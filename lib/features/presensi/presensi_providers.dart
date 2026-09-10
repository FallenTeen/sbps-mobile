import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/outbox_sync_service.dart';
import '../../core/outbox/pending_action.dart';
import '../../core/photo_compression_service.dart';
import '../auth/auth_providers.dart';
import 'models/presensi_hari_ini.dart';
import 'presensi_repository.dart';
import 'models/titik.dart';

final presensiRepositoryProvider = Provider<PresensiRepository>(
  (ref) => PresensiRepository(api: ref.watch(apiClientProvider)),
);

final photoCompressionProvider = Provider<PhotoCompressionService>(
  (ref) => PhotoCompressionService(),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

/// Daftar titik aktif — di-refresh saat pull-to-refresh.
final titikAktifProvider = FutureProvider.autoDispose<List<Titik>>(
  (ref) => ref.watch(presensiRepositoryProvider).getTitikAktif(),
);

/// Daftar penugasan aktif (kosong bila user tanpa data karyawan).
final assignmentsProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(presensiRepositoryProvider).getAssignments(),
);

/// Titik yang dipilih user untuk alur check-in (Fase A1.4).
class SelectedTitikNotifier extends Notifier<Titik?> {
  @override
  Titik? build() => null;

  void select(Titik? titik) => state = titik;
}

final selectedTitikProvider = NotifierProvider<SelectedTitikNotifier, Titik?>(
  SelectedTitikNotifier.new,
);

/// Posisi GPS terakhir yang berhasil didapat di halaman titik kerja.
class CurrentPositionNotifier extends Notifier<Position?> {
  @override
  Position? build() => null;

  void update(Position? position) => state = position;
}

final currentPositionProvider =
    NotifierProvider<CurrentPositionNotifier, Position?>(
      CurrentPositionNotifier.new,
    );

// ---------------------------------------------------------------------------
// Fase A1.4 — Check-in/out via outbox
// ---------------------------------------------------------------------------

final outboxRepositoryProvider = Provider<OutboxRepository>((ref) {
  final repo = OutboxRepository();
  repo.onChanged = () => ref.read(pendingCountProvider.notifier).reload();
  ref.onDispose(() => repo.onChanged = null);
  return repo;
});

final outboxSyncServiceProvider = Provider<OutboxSyncService>((ref) {
  final service = OutboxSyncService(
    ref.watch(outboxRepositoryProvider),
    ref.watch(apiClientProvider),
  );
  service.onSyncCycleDone = () {
    unawaited(ref.read(pendingCountProvider.notifier).reload());
    // Presensi bisa saja baru terkirim di latar belakang.
    ref.invalidate(hariIniProvider);
  };
  ref.onDispose(service.dispose);
  return service;
});

/// Badge jumlah aksi outbox yang belum tersinkron.
class PendingCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> reload() async {
    state = await ref.read(outboxRepositoryProvider).countPending();
  }
}

final pendingCountProvider = NotifierProvider<PendingCountNotifier, int>(
  PendingCountNotifier.new,
);

/// Daftar data lokal yang belum berhasil dikirim ke server.
final pendingActionsProvider = FutureProvider<List<PendingAction>>(
  (ref) => ref.watch(outboxRepositoryProvider).pendingActions(),
);

/// Status presensi hari ini (belum_check_in / menunggu_check_out / selesai).
final hariIniProvider = FutureProvider.autoDispose<PresensiHariIni>(
  (ref) => ref.watch(presensiRepositoryProvider).getHariIni(),
);

/// Hasil alur submit check-in/out ke UI.
class CheckInResult {
  const CheckInResult({
    this.delivered = false,
    this.queued = false,
    this.data,
    this.error,
  });

  /// true = server menerima presensi.
  final bool delivered;

  /// true = offline/gagal jaringan, tersimpan di outbox menunggu sync.
  final bool queued;
  final Map<String, dynamic>? data;
  final String? error;

  String? get statusValidasi => data?['status_validasi']?.toString();

  bool get luarRadius => statusValidasi == 'luar_radius';
}

class PresensiSubmitState {
  const PresensiSubmitState({this.busy = false, this.phase});

  final bool busy;

  /// Fase aktif saat busy — untuk indikator kompres → kirim di UI.
  final UploadPhase? phase;
}

class PresensiSubmitController extends Notifier<PresensiSubmitState> {
  static const _uuid = Uuid();

  @override
  PresensiSubmitState build() => const PresensiSubmitState();

  /// Alur check-in/check-out:
  /// 1. validasi titik terpilih + posisi GPS;
  /// 2. buat [PendingAction] dengan Idempotency-Key baru (uuid v4);
  /// 3. enqueue → outbox mencoba kirim langsung; bila gagal/offline,
  ///    tetap tersimpan dan sync service mengirim ulang otomatis.
  Future<CheckInResult> submit({
    required PendingEndpoint endpoint,
    required String photoPath,
  }) async {
    if (state.busy) return const CheckInResult(error: 'Sedang memproses.');
    final titik = ref.read(selectedTitikProvider);
    final pos = ref.read(currentPositionProvider);
    if (titik == null) {
      return const CheckInResult(error: 'Pilih titik kerja terlebih dahulu.');
    }
    if (pos == null) {
      return const CheckInResult(
        error: 'Posisi GPS belum tersedia. Tunggu lokasi siap.',
      );
    }

    state = const PresensiSubmitState(
      busy: true,
      phase: UploadPhase.compressing,
    );
    try {
      AnalyticsService.presensiCheckinTap(
        endpoint == PendingEndpoint.presensiCheckIn ? 'check_in' : 'check_out',
      );
      // Fase A1.6: kompres dulu (maks ~500KB, sisi 1600px) — path hasil
      // kompresi yang masuk outbox, bukan file asli kamera.
      final compressed = await ref
          .read(photoCompressionProvider)
          .compress(photoPath);
      state = const PresensiSubmitState(busy: true, phase: UploadPhase.sending);

      final lat = pos.latitude.toStringAsFixed(6);
      final lng = pos.longitude.toStringAsFixed(6);
      final action = PendingAction(
        id: _uuid.v4(),
        clientUuid: _uuid.v4(),
        endpoint: endpoint,
        payloadJson: {
          if (endpoint == PendingEndpoint.presensiCheckIn) 'titik_id': titik.id,
          'latitude': lat,
          'longitude': lng,
          'photo_metadata[latitude]': lat,
          'photo_metadata[longitude]': lng,
          'device_id': ref.read(deviceInfoProvider).name,
        },
        photoLocalPath: compressed,
        createdAt: DateTime.now(),
        idempotencyKey: _uuid.v4(),
      );

      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref
          .read(outboxRepositoryProvider)
          .enqueue(action, sync.send);

      if (result.delivered) {
        ref.invalidate(hariIniProvider);
        AnalyticsService.presensiCheckinSynced();
        final raw = result.responseData;
        return CheckInResult(
          delivered: true,
          data: raw is Map ? Map<String, dynamic>.from(raw) : null,
        );
      }
      AnalyticsService.presensiCheckinQueued();
      return const CheckInResult(queued: true);
    } on ApiException catch (e) {
      return CheckInResult(error: e.message);
    } catch (_) {
      return const CheckInResult(error: 'Gagal memproses presensi. Coba lagi.');
    } finally {
      state = const PresensiSubmitState();
    }
  }
}

final presensiSubmitProvider =
    NotifierProvider<PresensiSubmitController, PresensiSubmitState>(
      PresensiSubmitController.new,
    );
