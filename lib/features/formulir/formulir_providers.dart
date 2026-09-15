import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/pending_action.dart';
import '../../core/photo_compression_service.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'formulir_repository.dart';
import 'models/formulir_lapangan.dart';

final formulirRepositoryProvider = Provider<FormulirRepository>(
  (ref) => FormulirRepository(api: ref.watch(apiClientProvider)),
);

/// Formulir hari ini — null bila belum diisi (mode form kosong).
final formulirHariIniProvider = FutureProvider.autoDispose<FormulirLapangan?>(
  (ref) => ref.watch(formulirRepositoryProvider).getHariIni(),
);

class FormulirSubmitState {
  const FormulirSubmitState({this.busy = false, this.phase});

  final bool busy;

  /// Fase aktif saat busy — untuk indikator kompres → kirim di UI.
  final UploadPhase? phase;
}

/// Hasil submit mengikuti pola [CheckInResult] presensi.
class FormulirResult {
  const FormulirResult({
    this.delivered = false,
    this.queued = false,
    this.error,
  });

  final bool delivered;
  final bool queued;
  final String? error;
}

class FormulirController extends Notifier<FormulirSubmitState> {
  static const _uuid = Uuid();
  static const _maksFoto = 5;

  @override
  FormulirSubmitState build() => const FormulirSubmitState();

  /// Submit formulir via outbox (endpointType `formulirSubmit`):
  /// teks wajib divalidasi dulu; foto opsional maks [_maksFoto] dikirim
  /// sebagai path lokal. Idempotency-Key baru per aksi.
  Future<FormulirResult> submit({
    required String aktivitasDilakukan,
    String? kondisiArea,
    String? kendala,
    String? catatanTambahan,
    List<String> photoPaths = const [],
  }) async {
    if (state.busy) return const FormulirResult(error: 'Sedang memproses.');
    final aktivitas = aktivitasDilakukan.trim();
    if (aktivitas.isEmpty) {
      return const FormulirResult(error: 'Uraian aktivitas wajib diisi.');
    }
    if (photoPaths.length > _maksFoto) {
      return const FormulirResult(error: 'Maksimal $_maksFoto foto.');
    }

    state = const FormulirSubmitState(
      busy: true,
      phase: UploadPhase.compressing,
    );
    try {
      // Fase A1.6: kompres tiap foto sebelum masuk outbox.
      final compressor = ref.read(photoCompressionProvider);
      final compressed = <String>[];
      for (final path in photoPaths) {
        compressed.add(await compressor.compress(path));
      }
      state = const FormulirSubmitState(busy: true, phase: UploadPhase.sending);

      final action = PendingAction(
        id: _uuid.v4(),
        clientUuid: _uuid.v4(),
        endpoint: PendingEndpoint.formulirSubmit,
        payloadJson: {
          'aktivitas_dilakukan': aktivitas,
          if ((kondisiArea ?? '').trim().isNotEmpty)
            'kondisi_area': kondisiArea!.trim(),
          if ((kendala ?? '').trim().isNotEmpty) 'kendala': kendala!.trim(),
          if ((catatanTambahan ?? '').trim().isNotEmpty)
            'catatan_tambahan': catatanTambahan!.trim(),
        },
        photoLocalPaths: compressed,
        createdAt: DateTime.now(),
        idempotencyKey: _uuid.v4(),
      );

      final result = await ref
          .read(outboxRepositoryProvider)
          .enqueue(action, _send);

      if (result.delivered) {
        ref.invalidate(formulirHariIniProvider);
        return const FormulirResult(delivered: true);
      }
      return const FormulirResult(queued: true);
    } on ApiException catch (e) {
      return FormulirResult(error: e.message);
    } catch (_) {
      return const FormulirResult(
        error: 'Gagal memproses formulir. Coba lagi.',
      );
    } finally {
      state = const FormulirSubmitState();
    }
  }

  /// Percobaan kirim pertama memakai sync service (pola sama dengan
  /// presensi supaya retry/backoff identik).
  Future<OutboxSendResult> _send(PendingAction action) =>
      ref.read(outboxSyncServiceProvider).send(action);
}

final formulirSubmitProvider =
    NotifierProvider<FormulirController, FormulirSubmitState>(
      FormulirController.new,
    );
