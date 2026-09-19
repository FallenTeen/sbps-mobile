import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../analytics_service.dart';
import '../api_client.dart';
import 'outbox_repository.dart';
import 'pending_action.dart';

/// Layanan sinkronisasi outbox:
/// - mengirim ulang aksi pending saat perangkat online;
/// - backoff eksponensial per aksi, maksimum 5 percobaan otomatis;
/// - satu aksi dikirim pada satu waktu (urut createdAt).
class OutboxSyncService {
  OutboxSyncService(
    this._repo,
    this._api, {
    Stream<List<ConnectivityResult>> Function()? connectivityStream,
    Duration reconnectDebounce = const Duration(seconds: 2),
  }) : _connectivityStream = connectivityStream ??
           (() => Connectivity().onConnectivityChanged),
       _reconnectDebounce = reconnectDebounce;

  static const _maxAttempts = 5;

  final OutboxRepository _repo;
  final ApiClient _api;

  /// Sumber event konektivitas. Dapat di-inject pada test; default memakai
  /// plugin `connectivity_plus`.
  final Stream<List<ConnectivityResult>> Function() _connectivityStream;

  /// Jendela coalescing untuk lonjakan event konektivitas
  /// (OFF→ON→OFF→ON) agar tidak meluncurkan banyak siklus sync.
  final Duration _reconnectDebounce;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  Timer? _reconnectTimer;
  bool _syncing = false;

  /// true bila ada permintaan force-sync yang datang saat siklus lain
  /// berjalan — dijalankan sekali lagi setelah siklus tersebut selesai,
  /// sehingga trigger manual/resume tidak hilang begitu saja.
  bool _forceSyncQueued = false;

  /// Aksi yang sedang dikirim sekarang, dipetakan ke future hasilnya.
  /// Caller kedua untuk aksi yang sama (mis. `enqueue` dan worker `syncNow`
  /// yang memuat snapshot sama) JOIN future yang sama — SATU request nyata,
  /// semua caller menerima hasil asli. Tanpa ini, caller kedua menerima
  /// `queued` (delivered:false) padahal request berhasil dikirim, sehingga
  /// `enqueue` menandai retryable dan UI menampilkan "Gagal menyimpan"
  /// padahal data aman dan terkirim beberapa detik kemudian.
  final Map<String, Future<OutboxSendResult>> _inFlightActions = {};

  /// Dipanggil setelah siklus sync selesai (sukses maupun gagal) - dipakai
  /// provider untuk me-refresh state presensi.
  void Function()? onSyncCycleDone;

  /// Kirim satu aksi sekarang juga (dipakai untuk percobaan pertama
  /// dari [OutboxRepository.enqueue]).
  Future<OutboxSendResult> send(PendingAction action) async {
    final existing = _inFlightActions[action.id];
    if (existing != null) {
      // Aksi sama tengah dikirim worker lain (enqueue vs syncNow / timer /
      // reconnect). Join future yang sama: satu request, hasil asli.
      return await existing;
    }
    final future = _dispatch(action);
    _inFlightActions[action.id] = future;
    try {
      return await future;
    } finally {
      _inFlightActions.remove(action.id);
    }
  }

  /// Eksekusi pengiriman yang sebenarnya, diisolasi agar [send] bisa
  /// meng-join future aksi yang sama. Tidak pernah melempar: tiap kegagalan
  /// dikembalikan sebagai [OutboxSendResult] (kontrak `enqueue`).
  Future<OutboxSendResult> _dispatch(PendingAction action) async {
    try {
      try {
        await _repo.markSyncing(action.id);
      } catch (_) {}
      // Endpoint JSON (produksi): tanpa lampiran file, body dari
      // payloadData; client_uuid disuntik dari action.clientUuid —
      // SAMA di setiap retry agar backend idempotent.
      if (action.endpoint.isJson) {
        final body = <String, dynamic>{...action.payloadData};
        var path = action.endpoint.path;
        if (action.endpoint == PendingEndpoint.produksiSelesai) {
          final sessionId = body.remove('session_id');
          if (sessionId == null || sessionId.toString().isEmpty) {
            return const OutboxSendResult(
              delivered: false,
              permanentlyFailed: true,
              errorMessage: 'ID sesi produksi hilang dari antrean.',
            );
          }
          path = '$path/$sessionId';
        }
        // Workshop & request sparepart: path dinamis dengan id job di payload.
        if (action.endpoint == PendingEndpoint.workshopMulai ||
            action.endpoint == PendingEndpoint.workshopSelesai ||
            action.endpoint == PendingEndpoint.workshopRequestSparepart) {
          final jobId = body.remove('job_id');
          if (jobId == null || jobId.toString().isEmpty) {
            return const OutboxSendResult(
              delivered: false,
              permanentlyFailed: true,
              errorMessage: 'ID job servis hilang dari antrean.',
            );
          }
          path = path.replaceAll('{id}', jobId.toString());
        }
        await _api.post<Object?>(
          path,
          body: <String, dynamic>{...body, 'client_uuid': action.clientUuid},
          headers: {
            'Idempotency-Key': action.idempotencyKey,
          },
        );
        return const OutboxSendResult(delivered: true);
      }

      // Helper presensi: path dinamis /armada/helper/{helperId}/presensi.
      // Foto bukti todo workshop: path /workshop/job/{jobId}/todo/{todoId}/photo.
      var multipartPath = action.endpoint.path;
      if (action.endpoint == PendingEndpoint.helperPresensi) {
        final helperId = action.payloadJson['helper_id'];
        if (helperId == null || helperId.isEmpty) {
          return const OutboxSendResult(
            delivered: false,
            permanentlyFailed: true,
            errorMessage: 'ID helper hilang dari antrean.',
          );
        }
        multipartPath = '/armada/helper/$helperId/presensi';
      } else if (action.endpoint == PendingEndpoint.workshopTodoPhoto) {
        final jobId = action.payloadJson['job_id'];
        final todoId = action.payloadJson['todo_id'];
        if (jobId == null || jobId.isEmpty || todoId == null || todoId.isEmpty) {
          return const OutboxSendResult(
            delivered: false,
            permanentlyFailed: true,
            errorMessage: 'ID job/todo foto hilang dari antrean.',
          );
        }
        multipartPath = '/workshop/job/$jobId/todo/$todoId/photo';
      }

      final specs = switch (action.endpoint) {
        // Formulir lapangan: banyak foto dengan field `photos[]`.
        PendingEndpoint.formulirSubmit => [
          for (final path in action.photoLocalPaths)
            MultipartFileSpec('photos[]', path),
        ],
        // Checklist major: foto per item dikirim dengan field `photos[]`
        // (posisi sesuai `photo_index` di payload items).
        PendingEndpoint.armadaChecklistMajor => [
          for (final path in action.photoLocalPaths)
            MultipartFileSpec('photos[]', path),
        ],
        // Upload media generik (Fase A2.7): field `files[]`, 1-10 file.
        PendingEndpoint.uploadMedia => [
          for (final path in action.photoLocalPaths)
            MultipartFileSpec('files[]', path),
        ],
        // Presensi & helper presensi: satu foto wajib dengan field `photo`.
        _ => [
          if (action.photoLocalPath != null)
            MultipartFileSpec('photo', action.photoLocalPath!),
        ],
      };
      if (specs.isEmpty &&
          action.endpoint != PendingEndpoint.armadaChecklistMajor &&
          action.endpoint != PendingEndpoint.formulirSubmit) {
        return const OutboxSendResult(
          delivered: false,
          permanentlyFailed: true,
          errorMessage: 'File lampiran tidak ditemukan di perangkat.',
        );
      }
      final response = await _api.postMultipart<Object?>(
        multipartPath,
        fields: {
          ...action.payloadJson,
          // Endpoint /upload mensyaratkan client_uuid sebagai form field
          // (bukan hanya header Idempotency-Key) — nilai SAMA tiap retry.
          if (action.endpoint.isUploadMedia) 'client_uuid': action.clientUuid,
        },
        files: specs,
        headers: {
          // SAMA persis di setiap retry — jangan generate ulang,
          // jangan dipakai ulang antar PendingAction berbeda.
          'Idempotency-Key': action.idempotencyKey,
        },
      );
      return OutboxSendResult(delivered: true, responseData: response.data);
    } on ApiException catch (e) {
      // 4xx: validasi/konflik tidak akan membaik dengan retry.
      // Catatan: dengan Idempotency-Key aktif, retry key yang sama TIDAK
      // menghasilkan 422 "sudah check-in" — respons asli dikembalikan.
      // 422 di sini berarti konflik sungguhan (mis. sudah check-in lewat
      // jalur lain) atau payload invalid.
      if ((e.statusCode ?? 0) >= 400 && (e.statusCode ?? 0) < 500) {
        return OutboxSendResult(
          delivered: false,
          permanentlyFailed: true,
          errorMessage: e.message,
        );
      }
      return OutboxSendResult(delivered: false, errorMessage: e.message);
    } catch (e) {
      // Exception tak terduga (mis. file lampiran hilang / error parsing).
      // `send()` TIDAK BOLEH melempar: `enqueue()` memanggilnya SETELAH item
      // tersimpan, sehingga lemparan di sini menampilkan "gagal" di UI padahal
      // data sudah aman di outbox (persis pola "save failure → queue muncul"),
      // sekaligus menghentikan sisa antrean pada satu siklus `syncNow`.
      if (e is FileSystemException) {
        return const OutboxSendResult(
          delivered: false,
          permanentlyFailed: true,
          errorMessage:
              'File lampiran tidak ditemukan di perangkat. Ambil ulang foto lalu kirim lagi.',
        );
      }
      return OutboxSendResult(
        delivered: false,
        errorMessage:
            'Kendala teknis saat mengirim. Data tersimpan dan akan dicoba lagi.',
      );
    } finally {
      // Pembersihan map dikelola di `send()` agar caller kedua yang join
      // tetap mendapat hasil aksi yang sama (bukan `queued`).
    }
  }

  /// Proses semua aksi tertunda yang jatuh tempo (bukan sedang backoff).
  /// [ignoreBackoff] = paksa kirim (tombol sync / retry manual):
  /// melewati backoff DAN batas percobaan otomatis.
  Future<void> syncNow({bool ignoreBackoff = false}) async {
    if (_syncing) {
      // Sudah ada worker aktif. Alih-alih membuang trigger force (manual /
      // reconnect / resume), catat agar dijalankan sekali lagi setelah selesai.
      if (ignoreBackoff) _forceSyncQueued = true;
      return;
    }
    _syncing = true;
    var attempted = false;
    try {
      final actions = await _repo.pendingActions();
      for (final action in actions) {
        if (_inFlightActions.containsKey(action.id)) continue;
        if (!ignoreBackoff && _inBackoff(action)) continue;
        if (!ignoreBackoff && action.retryCount >= _maxAttempts) continue;
        attempted = true;

        final result = await send(action);
        if (result.delivered) {
          await _repo.remove(action.id);
          AnalyticsService.outboxItemSynced();
        } else if (result.permanentlyFailed) {
          await _repo.markFailed(action.id, result.errorMessage);
          AnalyticsService.outboxItemFail();
        } else {
          // Offline / 5xx — retryable: tetap pending + backoff dilanjutkan.
          await _repo.markRetryable(action.id, result.errorMessage);
          AnalyticsService.outboxItemFail();
        }
      }
    } finally {
      _syncing = false;
      // Panggil callback HANYA bila ada aksi yang benar-benar dicoba kirim.
      // Siklus kosong (antrean habis / semua masih backoff) tidak mengubah
      // state apa pun — memanggil onSyncCycleDone tiap menit memicu reload
      // provider + fetch jaringan (`presensi/hari-ini`) secara percuma
      // meski tab presensi sedang tidak dibuka (indexedStack tetap hidup).
      if (attempted) onSyncCycleDone?.call();
    }
    if (_forceSyncQueued) {
      _forceSyncQueued = false;
      await syncNow(ignoreBackoff: true);
    }
  }

  /// Backoff eksponensial: 15s, 30s, 60s, 120s, 240s.
  Duration _backoffFor(int retryCount) =>
      Duration(seconds: 15 * pow(2, max(0, retryCount - 1)).toInt());

  bool _inBackoff(PendingAction action) {
    final last = action.lastAttemptAt;
    if (last == null || action.retryCount == 0) return false;
    return DateTime.now().isBefore(last.add(_backoffFor(action.retryCount)));
  }

  /// Mulai listener konektivitas + timer periodik + sync awal saat app dibuka.
  /// Aman dipanggil ulang. [syncNow] awal tidak menunggu perubahan
  /// konektivitas/timer 1 menit — data yang diantre sebelum app ditutup
  /// langsung dicoba kirim saat app kembali dibuka (test: app open kembali).
  void start() {
    _connectivitySub ??= _connectivityStream().listen(
      handleConnectivityChange,
    );
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => syncNow());
    // App launch / relaunch: antrean dari sesi sebelumnya langsung di-flush
    // tanpa menunggu backoff (Acceptance #52). Tanpa ini, item yang sempat
    // kehabisan jatah retry otomatis akan "tersandera" sampai user menekan
    // Sync manual meski perangkat sudah online.
    unawaited(syncNow(ignoreBackoff: true));
  }

  /// Dipanggil listener `start()` untuk setiap perubahan konektivitas.
  /// Publik agar dapat diuji secara deterministik tanpa plugin.
  ///
  /// Event konektivitas hanyalah pemicu (WiFi connected != internet reachable,
  /// §11). Transisi ke online di-debounce untuk menggabungkan lonjakan
  /// (OFF→ON→OFF→ON, §15.4), lalu memaksa flush — jaringan yang baru kembali
  /// adalah konteks segar, termasuk untuk item yang sudah kehabisan jatah
  /// retry otomatis. Kegagalan tetap diklasifikasi ulang dari respons request.
  void handleConnectivityChange(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (!online) return;
    _reconnectTimer = Timer(_reconnectDebounce, () {
      _reconnectTimer = null;
      syncNow(ignoreBackoff: true);
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}
