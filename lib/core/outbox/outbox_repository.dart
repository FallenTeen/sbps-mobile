import 'dart:io';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'pending_action.dart';

/// Penyimpanan lokal outbox (Hive box `outbox`).
///
/// Setiap [PendingAction] disimpan sebagai string JSON ber-key id.
/// Semua mutasi memicu [onChanged] agar UI (badge pending) ikut ter-update.
class OutboxRepository {
  OutboxRepository({String boxName = 'outbox'}) : _boxName = boxName;

  final String _boxName;
  Box<String>? _box;
  Future<Box<String>>? _opening;

  /// Callback perubahan isi outbox — diisi oleh layer provider.
  void Function()? onChanged;

  Future<Box<String>> _ensureOpen() {
    final existing = _box;
    if (existing != null && existing.isOpen) return Future.value(existing);
    return _opening ??= Hive.openBox<String>(_boxName).then((box) {
      _box = box;
      return box;
    });
  }

  void _notify() => onChanged?.call();

  /// Simpan aksi baru dan langsung coba kirim lewat [send].
  /// Mengembalikan hasil percobaan pertama.
  Future<OutboxSendResult> enqueue(
    PendingAction action,
    Future<OutboxSendResult> Function(PendingAction) send,
  ) async {
    final box = await _ensureOpen();
    await box.put(action.id, action.encode());
    _notify();

    final result = await send(action);
    if (result.delivered) {
      await remove(action.id);
    } else {
      // Queued maupun permanentlyFailed sama-sama dicatat failed +
      // retryCount++ — permanen berhenti otomatis setelah batas percobaan.
      await markFailed(action.id, result.errorMessage);
    }
    return result;
  }

  /// Aksi yang masih harus dikirim: pending + syncing (crash recovery)
  /// + failed yang belum melewati batas retry.
  Future<List<PendingAction>> pendingActions() async {
    final box = await _ensureOpen();
    final actions = <PendingAction>[];
    for (final raw in box.values) {
      try {
        final action = PendingAction.decode(raw);
        if (action.status == PendingStatus.pending ||
            action.status == PendingStatus.syncing ||
            action.status == PendingStatus.failed) {
          actions.add(action);
        }
      } catch (_) {
        // Entri korup: buang supaya tidak menggantung seluruh sync.
        // Key tidak diketahui dari nilai; abaikan saja.
      }
    }
    actions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return actions;
  }

  Future<int> countPending() async {
    final box = await _ensureOpen();
    var n = 0;
    for (final raw in box.values) {
      try {
        final status = PendingAction.decode(raw).status;
        if (status != PendingStatus.success) n++;
      } catch (_) {}
    }
    return n;
  }

  /// Reset backoff dan tandai aksi gagal untuk percobaan manual.
  Future<void> markPending(String id) => _update(
    id,
    (a) => a
      ..status = PendingStatus.pending
      ..retryCount = 0
      ..errorMessage = null,
  );

  Future<void> markSyncing(String id) async =>
      _update(id, (a) => a..status = PendingStatus.syncing);

  Future<void> markFailed(String id, String? message) async => _update(
    id,
    (a) => a
      ..status = PendingStatus.failed
      ..lastAttemptAt = DateTime.now()
      ..retryCount = a.retryCount + 1
      ..errorMessage = message,
  );

  Future<void> remove(String id) async {
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

  Future<void> _update(String id, void Function(PendingAction) mutate) async {
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
}

/// Hasil satu percobaan pengiriman outbox.
class OutboxSendResult {
  const OutboxSendResult({
    required this.delivered,
    this.permanentlyFailed = false,
    this.responseData,
    this.errorMessage,
  });

  /// true = server menerima (respons sukses ATAU respons konflik idempotent
  /// yang membuktikan data sudah pernah masuk).
  final bool delivered;

  /// true = error tidak akan hilang dengan retry (payload invalid dsb).
  final bool permanentlyFailed;

  final Object? responseData;
  final String? errorMessage;

  static const queued = OutboxSendResult(delivered: false);
}
