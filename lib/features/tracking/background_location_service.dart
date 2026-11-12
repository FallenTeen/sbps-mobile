import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/location_service.dart';
import 'location_buffer_service.dart';
import 'tracking_isolate_upload.dart';

class BackgroundLocationService {
  static final instance = BackgroundLocationService._();
  BackgroundLocationService._();

  final _service = FlutterBackgroundService();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
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

  Future<void> startTracking() async {
    if (!_initialized) await initialize();
    if (!await _service.isRunning()) {
      await _service.startService();
    }
    _service.invoke('startTracking');
  }

  Future<void> stopTracking() async {
    _service.invoke('stopTracking');
  }

  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();

    _startGpsInterval(service);
    _startFlushTimer(service);
    _startConnectivityListener();

    service.on('startTracking').listen((_) {
      _startGpsInterval(service);
      _startFlushTimer(service);
    });

    service.on('stopTracking').listen((_) {
      _stopGpsInterval(service);
      _stopFlushTimer();
      _stopConnectivityListener();
      service.stopSelf();
    });
  }

  static Timer? _gpsTimer;
  static Timer? _flushTimer;
  static StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  static bool _isTracking = false;

  static void _startGpsInterval(ServiceInstance service) {
    if (_isTracking) return;
    _isTracking = true;

    unawaited(_gpsPing(service));

    _gpsTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(_gpsPing(service));
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

  static void _startFlushTimer(ServiceInstance service) {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(minutes: 4), (_) {
      unawaited(TrackingIsolateUpload.flush());
    });
    unawaited(TrackingIsolateUpload.flush());
  }

  static void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  static void _startConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        unawaited(TrackingIsolateUpload.flush());
      }
    });
  }

  static void _stopConnectivityListener() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  static Future<void> _gpsPing(ServiceInstance service) async {
    try {
      final location = LocationService();
      if (!await location.isServiceEnabled()) return;

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) return;

      final position = await location.getCurrentPosition();
      if (position == null) return;

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

      unawaited(TrackingIsolateUpload.flush());
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
