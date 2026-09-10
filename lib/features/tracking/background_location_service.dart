import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_config.dart';
import '../core/location_service.dart';

/// Background Location Service untuk Mandor Titik.
///
/// Menjalankan interval GPS ping (tiap 5-15 menit) walau app di-minimize,
/// selama masih dalam window check_in–check_out. Auto-cutoff jam kerja
/// (default 18:00) sebagai safety net.
///
/// Menggunakan `flutter_background_service` dengan foreground service
/// notification (wajib Android 8+).
class BackgroundLocationService {
  static final instance = BackgroundLocationService._();
  BackgroundLocationService._();

  final _service = FlutterBackgroundService();
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Inisialisasi background service + notification channel.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Setup local notifications untuk foreground service.
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    // Configure background service.
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
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
    final service = await _service.getEngine();
    service?.invoke('startTracking');
  }

  /// Hentikan background tracking.
  Future<void> stopTracking() async {
    final service = await _service.getEngine();
    service?.invoke('stopTracking');
    _service.invoke('stop');
  }

  /// Cek apakah service sedang berjalan.
  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    // Simpan reference ke service untuk komunikasi.
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();

      // Listen untuk perintah dari main isolate.
      service.on('startTracking').listen((_) {
        _startGpsInterval(service);
      });

      service.on('stopTracking').listen((_) {
        _stopGpsInterval(service);
        service.stopSelf();
      });

      service.on('setAsForeground').listen((_) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((_) {
        service.setAsBackgroundService();
      });
    }
  }

  static Timer? _gpsTimer;
  static bool _isTracking = false;

  static void _startGpsInterval(ServiceInstance service) {
    if (_isTracking) return;
    _isTracking = true;

    // Cek auto-cutoff.
    final now = DateTime.now();
    final cutoffHour = AppConfig.trackingCutoffHour;
    if (now.hour >= cutoffHour) {
      _stopGpsInterval(service);
      return;
    }

    // GPS ping pertama.
    _gpsPing(service);

    // Interval tiap 10 menit.
    _gpsTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      final current = DateTime.now();
      if (current.hour >= cutoffHour) {
        _stopGpsInterval(service);
        return;
      }
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
        'content': 'Tracking dihentikan (jam kerja selesai)',
      });
    }
  }

  static Future<void> _gpsPing(ServiceInstance service) async {
    try {
      final location = LocationService();
      final permission = await location.ensurePermission();
      if (!permission) return;

      final position = await location.getCurrentPosition();
      if (position == null) return;

      // Kirim data ke main isolate.
      service.invoke('update', {
        'title': 'SBPS Tracking',
        'content': 'Lokasi terkirim: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
      });

      // Data GPS dikirim via stream ke main isolate.
      service.invoke('gpsUpdate', {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toIso8601String(),
      });
    } catch (_) {
      // GPS ping gagal — diam saja, coba lagi di interval berikutnya.
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
