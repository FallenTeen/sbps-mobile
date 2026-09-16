import 'dart:async';
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
  OutboxSyncService(this._repo, this._api);

  static const _maxAttempts = 5;

  final OutboxRepository _repo;
  final ApiClient _api;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  bool _syncing = false;

  /// Dipanggil setelah siklus sync selesai (sukses maupun gagal) - dipakai
  /// provider untuk me-refresh state presensi.
  void Function()? onSyncCycleDone;

  /// Kirim satu aksi sekarang juga (dipakai untuk percobaan pertama
  /// dari [OutboxRepository.enqueue]).
  Future<OutboxSendResult> send(PendingAction action) async {
    try {
      await _repo.markSyncing(action.id);
    } catch (_) {}

    try {
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
        // Workshop: path dinamis dengan id job di payload.
        if (action.endpoint == PendingEndpoint.workshopMulai ||
            action.endpoint == PendingEndpoint.workshopSelesai) {
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
    }
  }

  /// Proses semua aksi tertunda yang jatuh tempo (bukan sedang backoff).
  Future<void> syncNow({bool ignoreBackoff = false}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final actions = await _repo.pendingActions();
      for (final action in actions) {
        if (!ignoreBackoff && _inBackoff(action)) continue;
        if (action.retryCount >= _maxAttempts) continue;

        final result = await send(action);
        if (result.delivered) {
          await _repo.remove(action.id);
          AnalyticsService.outboxItemSynced();
        } else {
          await _repo.markFailed(action.id, result.errorMessage);
          AnalyticsService.outboxItemFail();
        }
      }
    } finally {
      _syncing = false;
      onSyncCycleDone?.call();
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

  /// Mulai listener konektivitas + timer periodik. Aman dipanggil ulang.
  void start() {
    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncNow();
    });
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => syncNow());
  }

  void dispose() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _timer?.cancel();
    _timer = null;
  }
}
