import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/pending_action.dart';
import '../../core/photo_compression_service.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'upload_repository.dart';

final uploadRepositoryProvider = Provider<UploadRepository>(
  (ref) => UploadRepository(api: ref.watch(apiClientProvider)),
);

class UploadSubmitState {
  const UploadSubmitState({this.busy = false, this.phase});

  final bool busy;

  /// Fase aktif saat busy — kompres → kirim (reuse pola formulir).
  final UploadPhase? phase;
}

/// Hasil submit upload mengikuti pola [FormulirResult].
class UploadResult {
  const UploadResult({this.delivered = false, this.queued = false, this.error});

  final bool delivered;
  final bool queued;
  final String? error;
}

/// Controller dokumentasi produksi/QC via outbox — Fase A2.7.
///
/// Foto dikompres dulu ([PhotoCompressionService]), lalu dibuat SATU
/// PendingAction `uploadMedia` berisi semua file: client_uuid dibuat
/// sekali dan dikirim ulang persis saat retry (idempotent, tanpa file
/// dobel), sesuai kontrak §11.1. `subject_type`/`subject_id` memakai
/// nama class backend, mis. "ProductionSession" / "QcSample".
class UploadController extends Notifier<UploadSubmitState> {
  static const _uuid = Uuid();
  static const _maksFile = 10;

  @override
  UploadSubmitState build() => const UploadSubmitState();

  Future<UploadResult> submitDokumentasi({
    required List<String> photoPaths,
    String? subjectType,
    String? subjectId,
    String? catatan,
  }) async {
    if (state.busy) return const UploadResult(error: 'Sedang memproses.');
    if (photoPaths.isEmpty) {
      return const UploadResult(error: 'Pilih minimal satu foto.');
    }
    if (photoPaths.length > _maksFile) {
      return UploadResult(error: 'Maksimal $_maksFile foto per kiriman.');
    }

    state = const UploadSubmitState(busy: true, phase: UploadPhase.compressing);
    try {
      final compressor = ref.read(photoCompressionProvider);
      final compressed = <String>[];
      for (final path in photoPaths) {
        if (!File(path).existsSync()) continue;
        compressed.add(await compressor.compress(path));
      }
      if (compressed.isEmpty) {
        return const UploadResult(error: 'File tidak ditemukan di perangkat.');
      }

      state = const UploadSubmitState(busy: true, phase: UploadPhase.sending);
      final action = PendingAction(
        id: _uuid.v4(),
        clientUuid: _uuid.v4(),
        endpoint: PendingEndpoint.uploadMedia,
        payloadJson: {
          'file_type': 'foto',
          'kategori': 'dokumentasi',
          if ((subjectType ?? '').trim().isNotEmpty)
            'subject_type': subjectType!.trim(),
          if ((subjectId ?? '').trim().isNotEmpty)
            'subject_id': subjectId!.trim(),
          if ((catatan ?? '').trim().isNotEmpty) 'catatan': catatan!.trim(),
        },
        photoLocalPaths: compressed,
        createdAt: DateTime.now(),
        idempotencyKey: _uuid.v4(),
      );

      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref
          .read(outboxRepositoryProvider)
          .enqueue(action, sync.send);
      if (result.delivered) return const UploadResult(delivered: true);
      if (result.permanentlyFailed) {
        return UploadResult(
          error: result.errorMessage ?? 'Gagal mengunggah dokumentasi.',
        );
      }
      return const UploadResult(queued: true);
    } on ApiException catch (e) {
      // Termasuk 413/422 bila file melebihi 10MB atau format ditolak.
      return UploadResult(error: e.message);
    } catch (_) {
      return const UploadResult(error: 'Gagal mengunggah dokumentasi.');
    } finally {
      state = const UploadSubmitState();
    }
  }
}

final uploadSubmitProvider =
    NotifierProvider<UploadController, UploadSubmitState>(UploadController.new);
