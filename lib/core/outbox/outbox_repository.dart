import 'dart:async';
import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'pending_action.dart';

/// Penyimpanan lokal outbox (Hive box `outbox`).
///
/// Setiap [PendingAction] disimpan sebagai string JSON ber-key id.
/// Semua mutasi memicu [onChanged] agar UI (badge pending) ikut ter-update.
///
/// Semua operasi mutasi (dan baca-ubah-tulis seperti `_update`) di-serialize
/// lewat FIFO queue single-flight ([_gate]) agar tidak ada 2 operasi tulis
/// Hive yang bersaing mengakses box yang sama. Ini menutup race condition
/// pola "enqueue simpan → send markSyncing → enqueue remove" yang saling
/// timpa ketika `syncNow` worker berjalan bersamaan dengan user submit.
class OutboxRepository {
  OutboxRepository({String boxName = 'outbox'}) : _boxName = boxName;

  final String _boxName;
  Box<String>? _box;
  Future<Box<String>>? _opening;

  /// FIFO gate: operasi mutasi menunggu chain ini selesai sebelum jalan.
  /// Ibarat mutex cooperative — selamanya berisi Future yang menggantung
  /// operasi berikutnya. Setiap enqueue: `_gate = _gate.then(operasiBaru)`.
  Future<void> _gate = Future<void>.value();

  /// Set ID action yang sedang di dalam `enqueue` (box.put → send →
  /// post-process). Dipakai oleh `pendingActions` / call site lain untuk
  /// melewati ID yang masih di jendela enqueue (belum masuk ke
  /// `_inFlightActions` OutboxSyncService).
  final Set<String> _enqueuing = <String>{};

  /// Callback perubahan isi outbox - diisi oleh layer provider.
  void Function()? onChanged;

  /// true bila [id] sedang dalam proses enqueue (belum selesai put→send→
  /// update). Caller (mis. syncNow worker) sebaiknya melewati ID ini dan
  /// biarkan pemilik enqueue yang menyelesaikan.
  bool isEnqueuing(String id) => _enqueuing.contains(id);

  Future<Box<String>> _ensureOpen() {
    final existing = _box;
    if (existing != null && existing.isOpen) return Future.value(existing);
    return _opening ??= Hive.openBox<String>(_boxName).then((box) {
      _box = box;
      return box;
    });
  }

  void _notify() => onChanged?.call();

  /// Menjalankan [op] secara mutual-exclusion (FIFO serial). Operasi
  /// bersamaan menunggu giliran lewat chain [_gate]. Operasi hanya untuk
  /// operasi Hive box (put/delete/get iterate) agar tidak terjadi
  /// concurrent mutation. Operasi network (send) TIDAK boleh dibungkus ini
  /// karena akan menahan lock terlalu lama.
  Future<T> _serialized<T>(Future<T> Function() op) {
    final prev = _gate;
    final next = prev.then((_) => op(), onError: (_) => op());
    _gate = next.then((_) => null);
    return next;
  }

  /// Simpan aksi baru dan langsung coba kirim lewat [send].
  /// Mengembalikan hasil percobaan pertama.
  ///
  /// Alur lock-aware (menutup H1 — jendela box.put → _inFlightActions):
  /// 1. Tandai id dalam `_enqueuing` (sebelum box.put).
  /// 2. Serialized: box.put + _notify (Hive write terkunci serial).
  /// 3. Luar lock: panggil `send(action)` (network call, bisa lama).
  /// 4. Serialized: remove / markFailed / markRetryable (lagi terkunci).
  /// 5. `finally`: hapus dari `_enqueuing`.
  ///
  /// `pendingActions()` secara otomatis menyaring id yang masih `_enqueuing`,
  /// sehingga `syncNow` worker tidak memproses id yang tengah di-enqueue.
  Future<OutboxSendResult> enqueue(
    PendingAction action,
    Future<OutboxSendResult> Function(PendingAction) send,
  ) async {
    _enqueuing.add(action.id);
    try {
      await _serialized(() async {
        final box = await _ensureOpen();
        await box.put(action.id, action.encode());
        _notify();
      });

      OutboxSendResult result;
      try {
        result = await send(action);
      } catch (e) {
        // `send()` (OutboxSyncService.send) berkontrak TIDAK PERNAH melempar.
        // Kalau tetap ada exception bocor (sangat jarang), perlakukan sebagai
        // retryable dengan pesan umum: data tetap tersimpan aman.
        final msg = e is Exception ? e.toString() : null;
        result = OutboxSendResult(
          delivered: false,
          errorMessage: msg ?? 'Kendala teknis saat mengirim.',
        );
      }

      await _serialized(() async {
        if (result.delivered) {
          await _removeLocked(action.id);
        } else if (result.permanentlyFailed) {
            await _markFailedLocked(action.id, result.errorMessage);
          } else {
            await _markRetryableLocked(action.id, result.errorMessage);
          }
      });
      return result;
    } finally {
      _enqueuing.remove(action.id);
    }
  }

  /// Aksi yang masih harus dikirim: pending + syncing (crash recovery)
  /// + failed yang belum melewati batas retry.
  ///
  /// ID yang masih di dalam alur `enqueue` (belum selesai post-process)
  /// DISARING KELUAR — syncNow worker tidak boleh memperebutkan action
  /// yang sedang dikirim oleh jalur `enqueue.send` langsung.
  Future<List<PendingAction>> pendingActions() => _serialized(() async {
    final box = await _ensureOpen();
    final actions = <PendingAction>[];
    for (final raw in box.values) {
      try {
        final action = PendingAction.decode(raw);
        if (_enqueuing.contains(action.id)) continue;
        if (action.status == PendingStatus.pending ||
            action.status == PendingStatus.syncing ||
            action.status == PendingStatus.failed) {
          actions.add(action);
        }
      } catch (_) {
        // Entri korup: buang supaya tidak menggantung seluruh sync.
      }
    }
    actions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return actions;
  });

  Future<int> countPending() => _serialized(() async {
    final box = await _ensureOpen();
    var n = 0;
    for (final raw in box.values) {
      try {
        final action = PendingAction.decode(raw);
        if (_enqueuing.contains(action.id)) continue;
        if (action.status != PendingStatus.success) n++;
      } catch (_) {}
    }
    return n;
  });

  // ─── Versi LOCKED (dipanggil di dalam _serialized block) ────────────────

  Future<void> _updateLocked(
    String id,
    void Function(PendingAction) mutate,
  ) async {
    final box = await _ensureOpen();
    final raw = box.get(id);
    if (raw == null) return;
    try {
      final action = PendingAction.decode(raw);
      mutate(action);
      await box.put(id, action.encode());
      _notify();
    } catch (_) {}
  }

  Future<void> _markPendingLocked(String id) => _updateLocked(
    id,
    (a) => a
      ..status = PendingStatus.pending
      ..retryCount = 0
      ..errorMessage = null,
  );

  Future<void> _markSyncingLocked(String id) =>
      _updateLocked(id, (a) => a..status = PendingStatus.syncing);

  Future<void> _markRetryableLocked(String id, String? message) => _updateLocked(
    id,
    (a) => a
      ..status = PendingStatus.pending
      ..lastAttemptAt = DateTime.now()
      ..retryCount = a.retryCount + 1
      ..errorMessage = message,
  );

  Future<void> _markFailedLocked(String id, String? message) => _updateLocked(
    id,
    (a) => a
      ..status = PendingStatus.failed
      ..lastAttemptAt = DateTime.now()
      ..retryCount = a.retryCount + 1
      ..errorMessage = message,
  );

  Future<void> _removeLocked(String id) async {
    final box = await _ensureOpen();
    final raw = box.get(id);
    await box.delete(id);
    _notify();
    if (raw == null) return;
    try {
      final action = PendingAction.decode(raw);
      final paths = [
        if (action.photoLocalPath != null) action.photoLocalPath!,
        ...action.photoLocalPaths,
      ];
      for (final path in paths) {
        final file = File(path);
        if (file.existsSync()) file.deleteSync();
      }
    } catch (_) {}
  }

  // ─── Versi PUBLIK (auto-wrap _serialized) ───────────────────────────────

  /// Reset backoff dan tandai aksi gagal untuk percobaan manual.
  Future<void> markPending(String id) =>
      _serialized(() => _markPendingLocked(id));

  Future<void> markSyncing(String id) =>
      _serialized(() => _markSyncingLocked(id));

  /// Gagal retryable (jaringan / 5xx): status DIPERTAHANKAN `pending`
  /// (menunggu jaringan) tapi backoff diperbarui. Hanya error permanen
  /// (4xx, via [markFailed]) yang tampil merah "Gagal dikirim".
  Future<void> markRetryable(String id, String? message) =>
      _serialized(() => _markRetryableLocked(id, message));

  Future<void> markFailed(String id, String? message) =>
      _serialized(() => _markFailedLocked(id, message));

  Future<void> remove(String id) =>
      _serialized(() => _removeLocked(id));
}

/// Hasil satu percobaan pengiriman outbox.
class OutboxSendResult {
  const OutboxSendResult({
    required this.delivered,
    this.permanentlyFailed = false,
    this.transientRetryable = false,
    this.responseData,
    this.errorMessage,
  });

  /// true = server menerima (respons sukses ATAU respons konflik idempotent
  /// yang membuktikan data sudah pernah masuk).
  final bool delivered;

  /// true = error tidak akan hilang dengan retry (payload invalid dsb).
  final bool permanentlyFailed;

  /// true = error ini dianggap transient (connectivity flutter, 5xx,
  /// DioException tanpa response). `_sendWithTransientRetry` hanya
  /// melakukan retry tambahan 1x jika field ini true, agar request yang
  /// sebenarnya cuma salah timing handover jaringan tidak langsung
  /// masuk antrean offline dan tidak memicu snackbar "queued" palsu.
  final bool transientRetryable;

  final Object? responseData;
  final String? errorMessage;

  static const queued = OutboxSendResult(delivered: false);
}
