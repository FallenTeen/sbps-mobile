import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/app_preferences.dart';
import '../../core/outbox/pending_action.dart';
import '../auth/auth_providers.dart';
import '../presensi/models/presensi_hari_ini.dart';
import '../presensi/presensi_providers.dart';
import 'background_location_service.dart';
import 'location_buffer_service.dart';
import 'models.dart';
import 'tracking_repository.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>(
  (ref) => TrackingRepository(api: ref.watch(apiClientProvider)),
);

const _kAlwaysPromptLastKey = 'always_prompt_last_ms';

/// Ubah pesan teknis (server/ApiException/jaringan) menjadi bahasa sehari-hari
/// sebelum ditampilkan ke pengguna. Pesan yang sudah sederhana diteruskan.
String? mapTrackingMessage(String? raw) {
  if (raw == null) return null;
  final msg = raw.trim();
  if (msg.isEmpty) return null;
  final lower = msg.toLowerCase();
  if (lower.contains('unauthenticated') ||
      lower.contains('tidak terautentikasi') ||
      lower.contains('401')) {
    return 'Sesi berakhir, silakan login ulang.';
  }
  if (lower.contains('internal server error') ||
      lower.contains('server error') ||
      lower.contains('500')) {
    return 'Server sedang bermasalah, lokasi tetap disimpan di HP.';
  }
  if (lower.contains('connection') ||
      lower.contains('timeout') ||
      lower.contains('dioexception') ||
      lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('internet') ||
      lower.contains('host') ||
      lower.contains('gagal mengirim')) {
    return 'Koneksi internet bermasalah, lokasi tetap disimpan di HP.';
  }
  return msg;
}

/// Kapan boleh memunculkan dialog izin Sepanjang Waktu lagi:
/// maksimal sekali per 7 hari (dan sekali per sesi).
bool shouldPromptAlwaysPermission({
  required bool promptedThisSession,
  required DateTime? lastPromptAt,
  required DateTime now,
}) {
  if (promptedThisSession) return false;
  if (lastPromptAt == null) return true;
  return now.difference(lastPromptAt) >= const Duration(days: 7);
}

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

/// Scheduler tracking GPS untuk semua karyawan login:
/// - gate: user login + presensi terbuka (menunggu check-out);
/// - buffer GPS via [LocationBufferService]; titik dari background service
///   isolate digabung dari Hive saat flush;
/// - kirim batch tiap 4 menit ATAU begitu online kembali;
/// - satu batch = satu batch_id, dipakai ulang persis pada retry
///   (idempotent, tidak pernah dipecah/digabung);
/// - 422 "belum check-in" tidak membuang data (window server 36 jam);
///   titik/batch kemarin dibuang otomatis di [LocationBufferService._pruneStale].
class TrackingScheduler extends Notifier<TrackingStatus> {
  static const _uuid = Uuid();
  static const _flushInterval = Duration(minutes: 4);
  static const _maxBatch = 450;

  Timer? _flushTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _flushing = false;
  bool _alwaysPrompted = false;

  @override
  TrackingStatus build() {
    // Reaksi otomatis terhadap login/logout & presensi buka/tutup.
    ref.listen(authControllerProvider, (_, _) => evaluate());
    ref.listen(hariIniProvider, (_, _) => evaluate());
    ref.onDispose(_teardown);
    Future.microtask(evaluate);
    return const TrackingStatus();
  }

  LocationBufferService get _buffer => ref.read(locationBufferProvider);

  Future<DateTime?> _lastAlwaysPromptAt() async {
    final raw = await AppPreferences.getString(_kAlwaysPromptLastKey);
    final ms = int.tryParse(raw ?? '');
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> _shouldRun() async {
    if (ref.read(authControllerProvider).value == null) return false;

    try {
      final presensi = await ref.read(hariIniProvider.future);
      final open = presensi.status == PresensiStatus.menungguCheckOut;
      await LocationBufferService.setPresensiOpen(open);
      return open;
    } catch (_) {
      if (await LocationBufferService.getPresensiOpenCached()) return true;
      try {
        final pending = await ref.read(outboxRepositoryProvider).pendingActions();
        if (pending.any((a) => a.endpoint == PendingEndpoint.presensiCheckIn)) {
          await LocationBufferService.setPresensiOpen(true);
          return true;
        }
      } catch (_) {}
      return state.running;
    }
  }

  /// Selaraskan status berjalan dengan kondisi saat ini. Aman dipanggil
  /// berkali-kali.
  Future<void> evaluate() async {
    if (await _shouldRun()) {
      await _start();
    } else {
      _stop();
    }
  }

  Future<void> _start() async {
    if (_buffer.isRunning && state.running) return;

    final error = await _buffer.start();
    if (error != null) {
      state = state.copyWith(running: false, message: mapTrackingMessage(error));
      return;
    }

    // Minta izin ALWAYS maksimal sekali per sesi dan sekali per 7 hari.
    // Bila ditolak permanen, JANGAN tampilkan dialog OS: biarkan banner di
    // titik kerja mengarahkan ke Pengaturan. Tracking tetap berjalan.
    final location = ref.read(locationServiceProvider);
    LocationPermission permission;
    try {
      permission = await location.currentPermission();
    } catch (_) {
      permission = LocationPermission.unableToDetermine;
    }
    if (permission == LocationPermission.deniedForever) {
      // Jalur banner (_AlwaysPermissionBanner) yang menangani, tanpa dialog OS.
    } else if (permission != LocationPermission.always) {
      final lastAt = await _lastAlwaysPromptAt();
      if (shouldPromptAlwaysPermission(
        promptedThisSession: _alwaysPrompted,
        lastPromptAt: lastAt,
        now: DateTime.now(),
      )) {
        _alwaysPrompted = true;
        unawaited(
          AppPreferences.setString(
            _kAlwaysPromptLastKey,
            DateTime.now().millisecondsSinceEpoch.toString(),
          ),
        );
        final ok = await location.ensureAlwaysPermission();
        if (!ok) {
          state = state.copyWith(
            message:
                'Izin lokasi belakang belum aktif - lokasi terkirim hanya saat aplikasi dibuka.',
          );
        }
      }
    }

    // Start background location service untuk tracking berkelanjutan
    // saat app di-minimize (punya izin always).
    if (await location.hasAlwaysPermission()) {
      try {
        await BackgroundLocationService.instance.initialize();
        await BackgroundLocationService.instance.startTracking();
      } catch (_) {
        // Background service gagal - foreground tracking tetap jalan.
      }
    }

    state = state.copyWith(
      running: true,
      message: null,
      pendingPoints: _buffer.count,
    );

    unawaited(LocationBufferService.setTrackingDesired(true));
    unawaited(_scheduleOemRestart());

    unawaited(LocationBufferService.cacheAuthToken(
      await ref.read(tokenStorageProvider).readToken(),
    ));
    unawaited(LocationBufferService.cacheActiveRole(
      await ref.read(tokenStorageProvider).readActiveRole(),
    ));

    _connectivitySub ??= Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) flush();
    });
    _flushTimer ??= Timer.periodic(_flushInterval, (_) => flush());

    unawaited(flush());
  }

  /// FASE SELANJUTNYA (WorkManager): pemanggilan ini adalah titik pasang
  /// WorkManager untuk auto-restart tracking saat OEM mematikan proses dan
  /// aplikasi tidak pernah dibuka lagi. Saat ini no-op - alternatif yang
  /// berjalan: flag tracking_desired + restart saat app dibuka/resume,
  /// plus push FCM dari backend (command tracking:stale-reminder) yang
  /// mengingatkan karyawan membuka aplikasi.
  ///
  /// Cara pasang nanti:
  /// 1. flutter pub add workmanager
  /// 2. Registrasi callback di main.dart:
  ///    Workmanager().initialize(...); Workmanager().registerPeriodicTask(
  ///      'tracking-restart', 'trackingRestart', frequency: Duration(minutes: 15));
  /// 3. Di callback DispatcherTask: jika LocationBufferService.isTrackingDesired()
  ///    dan service tidak berjalan, panggil ulang mekanisme start tracking.
  /// 4. AndroidManifest perlu izin dari plugin (tambah di Info.plist untuk iOS
  ///    tidak wajib karena iOS menangani sendiri).
  Future<void> _scheduleOemRestart() async {
    // No-op sampai WorkManager dipasang di fase selanjutnya.
  }

  void _stop({String? message}) {
    _teardown();

    // Stop background location service.
    BackgroundLocationService.instance.stopTracking();
    unawaited(LocationBufferService.setTrackingDesired(false));

    state = state.copyWith(
      running: false,
      message: message ?? 'Tracking tidak aktif.',
    );
  }

  /// Kirim isi buffer sebagai SATU batch idempotent.
  Future<void> flush() async {
    if (!state.running || _flushing) return;
    if (await LocationBufferService.isAuthBlocked()) return;
    final gotLock = await LocationBufferService.tryAcquireFlushLock();
    if (!gotLock) return;
    _flushing = true;
    try {
      // Cache token/role ke Hive agar background isolate bisa upload
      // tanpa platform channel (flutter_secure_storage sering gagal di isolate).
      final t = await ref.read(tokenStorageProvider).readToken();
      final r = await ref.read(tokenStorageProvider).readActiveRole();
      await LocationBufferService.cacheAuthToken(t);
      await LocationBufferService.cacheActiveRole(r);
      // Rollover hari baru SEBELUM membaca batch - batch pending
      // milik kemarin dibuang, jadi tak pernah diretry percuma.
      await _buffer.pruneStale();
      var pending = await _buffer.readPendingBatch();
      List<TrackPoint> points;
      String batchId;

      if (pending != null) {
        // Retry batch yang sama PERSIS - batch_id & isi jangan diubah.
        // Batasi ukuran agar tidak melebihi max_batch backend.
        if (pending.points.length > _maxBatch) {
          final chunk = pending.points.take(_maxBatch).toList();
          await _buffer.savePendingBatch(pending.batchId, chunk);
          batchId = pending.batchId;
          points = chunk;
        } else {
          batchId = pending.batchId;
          points = pending.points;
        }
      } else {
        // Gabungkan titik yang ditulis service isolate langsung
        // ke Hive - buffer in-memory tak melihatnya sendirian.
        await _buffer.syncFromStore();
        final all = _buffer.snapshot();
        if (all.isEmpty) {
          state = state.copyWith(pendingPoints: 0);
          return;
        }
        points = all.take(_maxBatch).toList();
        batchId = _uuid.v4();
        await _buffer.savePendingBatch(batchId, points);
      }
      if (points.isEmpty) {
        await _buffer.clearPendingBatch();
        state = state.copyWith(pendingPoints: _buffer.count);
        return;
      }

      try {
        await ref
            .read(trackingRepositoryProvider)
            .sendBatch(batchId: batchId, points: points);
        // Sukses (termasuk duplicate:true): aman hapus dari perangkat.
        await _buffer.removeByIds(points.map((p) => p.id).toSet());
        await _buffer.clearPendingBatch();
        await LocationBufferService.clearAuthBlocked();
        state = state.copyWith(
          lastSentAt: DateTime.now(),
          pendingPoints: _buffer.count,
          message: null,
        );
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          await LocationBufferService.setAuthBlocked(const Duration(hours: 1));
        }
        state = state.copyWith(message: mapTrackingMessage(e.message));
      }
    } catch (_) {
      state = state.copyWith(
        message: mapTrackingMessage('Gagal mengirim lokasi.'),
      );
    } finally {
      _flushing = false;
      await LocationBufferService.releaseFlushLock();
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
