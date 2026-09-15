import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/app_config.dart';
import '../auth/auth_providers.dart';
import '../portal/portal_providers.dart';
import '../presensi/presensi_providers.dart';
import 'background_location_service.dart';
import 'location_buffer_service.dart';
import 'models.dart';
import 'tracking_repository.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(api: ref.watch(apiClientProvider)),
);

final locationBufferProvider = Provider<LocationBufferService>((ref) {
  final service = LocationBufferService(ref.watch(locationServiceProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// Status tracking untuk UI (chip di home Mandor Titik).
class TrackingStatus {
  const TrackingStatus({
    this.running = false,
    this.pendingPoints = 0,
    this.lastSentAt,
    this.message,
  });

  final bool running;
  final int pendingPoints;
  final DateTime? lastSentAt;

  /// Penjelasan kenapa tidak berjalan / error kirim terakhir.
  final String? message;

  TrackingStatus copyWith({
    bool? running,
    int? pendingPoints,
    DateTime? lastSentAt,
    String? message,
  }) => TrackingStatus(
    running: running ?? this.running,
    pendingPoints: pendingPoints ?? this.pendingPoints,
    lastSentAt: lastSentAt ?? this.lastSentAt,
    message: message,
  );
}

/// Scheduler Live Tracking (Fase A2.4):
/// - aktif HANYA untuk portal proyek + role `Mandor Titik` yang login;
/// - buffer GPS via [LocationBufferService];
/// - kirim batch tiap 4 menit ATAU begitu online kembali;
/// - satu batch = satu batch_id: dibuat sekali sebelum kirim pertama dan
///   dipakai ulang persis pada retry (tidak pernah dipecah/digabung);
/// - titik dihapus dari buffer hanya setelah batch terkirim sukses.
///
/// 422 "belum check-in"/"belum terhubung karyawan" TIDAK membuang data —
/// batch dipertahankan untuk dicoba lagi nanti hari itu.
class TrackingScheduler extends Notifier<TrackingStatus> {
  static const _uuid = Uuid();
  static const _flushInterval = Duration(minutes: 4);

  Timer? _flushTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;

  @override
  TrackingStatus build() {
    // Reaksi otomatis terhadap login/logout & ganti role.
    ref.listen(authControllerProvider, (_, _) => evaluate());
    ref.listen(activeRoleProvider, (_, _) => evaluate());
    ref.onDispose(_teardown);
    Future.microtask(evaluate);
    return const TrackingStatus();
  }

  LocationBufferService get _buffer => ref.read(locationBufferProvider);

  bool get _shouldRun {
    final portal = ref.read(selectedPortalProvider).value;
    if (portal != AppPortal.proyek) return false;
    if (ref.read(authControllerProvider).value == null) return false;
    if (ref.read(activeRoleProvider) != 'Mandor Titik') return false;
    return DateTime.now().hour < AppConfig.trackingCutoffHour;
  }

  /// Selaraskan status berjalan dengan kondisi saat ini. Aman dipanggil
  /// berkali-kali.
  Future<void> evaluate() async {
    if (_shouldRun) {
      await _start();
    } else {
      _stop();
    }
  }

  Future<void> _start() async {
    if (_buffer.isRunning && state.running) return;

    final error = await _buffer.start();
    if (error != null) {
      state = state.copyWith(running: false, message: error);
      return;
    }

    // Start background location service untuk tracking berkelanjutan
    // saat app di-minimize.
    try {
      await BackgroundLocationService.instance.initialize();
      await BackgroundLocationService.instance.startTracking();
    } catch (_) {
      // Background service gagal — foreground tracking tetap jalan.
    }

    state = state.copyWith(
      running: true,
      message: null,
      pendingPoints: _buffer.count,
    );

    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flush());

    unawaited(flush());
  }

  void _stop({String? message}) {
    _teardown();

    // Stop background location service.
    BackgroundLocationService.instance.stopTracking();

    state = state.copyWith(
      running: false,
      message:
          message ??
          (DateTime.now().hour >= AppConfig.trackingCutoffHour
              ? 'Tracking berhenti — melewati jam cutoff.'
              : 'Tracking tidak aktif.'),
    );
  }

  /// Kirim isi buffer sebagai SATU batch idempotent.
  Future<void> flush() async {
    if (!state.running || _flushing) return;
    _flushing = true;
    try {
      var pending = await _buffer.readPendingBatch();
      List<TrackPoint> points;
      String batchId;

      if (pending != null) {
        // Retry batch yang sama PERSIS — batch_id & isi jangan diubah.
        batchId = pending.batchId;
        points = pending.points;
      } else {
        points = _buffer.snapshot();
        if (points.isEmpty) {
          state = state.copyWith(pendingPoints: 0);
          return;
        }
        batchId = _uuid.v4();
        await _buffer.savePendingBatch(batchId, points);
      }

      try {
        await ref
            .read(trackingRepositoryProvider)
            .sendBatch(batchId: batchId, points: points);
        // Sukses (termasuk duplicate:true): aman hapus dari perangkat.
        await _buffer.removeByIds(points.map((p) => p.id).toSet());
        await _buffer.clearPendingBatch();
        state = state.copyWith(
          lastSentAt: DateTime.now(),
          pendingPoints: _buffer.count,
          message: null,
        );
      } on ApiException catch (e) {
        // 422 belum check-in/karyawan, 429 rate limit, dsb: pertahankan
        // batch (batch_id sama) untuk percobaan berikutnya.
        state = state.copyWith(message: e.message);
      }
    } catch (_) {
      state = state.copyWith(message: 'Gagal mengirim lokasi.');
    } finally {
      _flushing = false;
    }
  }

  void _teardown() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _buffer.stop();
  }
}

final trackingSchedulerProvider =
    NotifierProvider<TrackingScheduler, TrackingStatus>(TrackingScheduler.new);

// ---------------------------------------------------------------------------
// Viewer (Owner / Admin Keuangan)
// ---------------------------------------------------------------------------

final activeUsersProvider = FutureProvider.autoDispose<List<ActiveUser>>(
  (ref) => ref.watch(trackingRepositoryProvider).getActiveUsers(),
);

final trailProvider = FutureProvider.autoDispose.family<TrailData, String>(
  (ref, userId) => ref.watch(trackingRepositoryProvider).getHariIni(userId),
);
