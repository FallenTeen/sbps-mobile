import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/location_service.dart';
import 'location_buffer_service.dart';

/// Background Location Service untuk SEMUA karyawan ber-presensi (§24 TODO A5/A6).
///
/// Menjalankan interval GPS ping (tiap 10 menit) walau app di-minimize,
/// selama presensi masih terbuka. Service isolate menulis titik LANGSUNG
/// ke buffer Hive (berulang saat process utama di-freeze) — tidak ada
/// cutoff jam 18:00; berhenti saat proses utama memanggil stopTracking
/// (check-out / logout).
class BackgroundLocationService {
  static final instance = BackgroundLocationService._();
  BackgroundLocationService._();

  final _service = FlutterBackgroundService();
  bool _initialized = false;

  /// Inisialisasi background service.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        // Android 14+ (targetSdk 34+): foreground service WAJIB punya
        // tipe. Tanpa ini startForeground melempar exception dan service
        // mati diam-diam (tertangkap catch di TrackingScheduler._start).
        foregroundServiceTypes: const [AndroidForegroundType.location],
        notificationChannelId: 'sbps_tracking',
        initialNotificationTitle: 'SBPS Tracking',
        initialNotificationContent: 'Merekam lokasi kerja...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Mulai background tracking.
  Future<void> startTracking() async {
    if (!_initialized) await initialize();
    // flutter_background_service 5.x: `invoke()` hanya mengirim pesan ke
    // service yang SUDAH berjalan. Service harus di-start eksplisit -
    // tanpa `startService()` tracking background tidak pernah hidup
    // (hanya foreground yang merekam).
    if (!await _service.isRunning()) {
      await _service.startService();
    }
    _service.invoke('startTracking');
  }

  /// Hentikan background tracking.
  Future<void> stopTracking() async {
    _service.invoke('stopTracking');
  }

  /// Cek apakah service sedang berjalan.
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    _startGpsInterval(service);

    service.on('startTracking').listen((_) {
      _startGpsInterval(service);
    });

    service.on('stopTracking').listen((_) {
      _stopGpsInterval(service);
      service.stopSelf();
    });
  }

  static Timer? _gpsTimer;
  static bool _isTracking = false;

  static void _startGpsInterval(ServiceInstance service) {
    if (_isTracking) return;
    _isTracking = true;

    _gpsPing(service);

    _gpsTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _gpsPing(service);
    });
  }

  static void _stopGpsInterval(ServiceInstance service) {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    _isTracking = false;

    if (service is AndroidServiceInstance) {
      service.invoke('update', {
        'title': 'SBPS Tracking',
        'content': 'Tracking dihentikan',
      });
    }
  }

  static Future<void> _gpsPing(ServiceInstance service) async {
    try {
      final location = LocationService();
      if (!await location.isServiceEnabled()) return;

      // Tanpa prompt while-in-use saja: service di background butuh
      // izin ALWAYS. Bila belum, jangan request di sini (dialog butuh
      // UI) — ping di-skip dan proses utama yang menuntaskan izin.
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) return;

      final position = await location.getCurrentPosition();
      if (position == null) return;

      // Tulis LANGSUNG ke buffer Hive agar titik tetap terkirim
      // walau process utama sudah dibunuh oleh OEM.
      await LocationBufferService.appendPointIsolate(
        lat: position.latitude,
        lng: position.longitude,
        timestamp: position.timestamp.toLocal(),
      );

      if (service is AndroidServiceInstance) {
        service.invoke('update', {
          'title': 'SBPS Tracking',
          'content':
              'Lokasi tercatat: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        });
      }
    } catch (_) {
      // GPS ping gagal — diam saja, coba lagi di interval berikutnya.
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
