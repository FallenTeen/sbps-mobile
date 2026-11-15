import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/location_service.dart';
import 'location_buffer_service.dart';
import 'tracking_isolate_upload.dart';

/// Channel notifikasi FGS tracking. WAJIB dibuat sebelum service start:
/// startForeground dengan channel yang tidak ada melempar
/// RemoteServiceException (Bad notification) dan Android membunuh app.
///
/// Versi 2: id channel diganti karena setting channel Android tidak bisa
/// diubah setelah dibuat — di sebagian perangkat, channel lama
/// `sbps_tracking` terlanjur terbentuk dengan importance default (bunyi +
/// heads-up tiap notifikasi di-post ulang). Channel baru dijamin silent,
/// channel lama dihapus.
const kTrackingNotificationChannelId = 'sbps_tracking_v2';
const _kOldTrackingChannelId = 'sbps_tracking';

class BackgroundLocationService {
  static final instance = BackgroundLocationService._();
  BackgroundLocationService._();

  final _service = FlutterBackgroundService();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _ensureTrackingChannel();

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        foregroundServiceTypes: const [AndroidForegroundType.location],
        notificationChannelId: kTrackingNotificationChannelId,
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
    // Guard anti-crash: startForeground tanpa notifikasi yang bisa
    // diposting (channel hilang/diblokir/notifikasi dimatikan) membuat
    // Android 12+ membunuh proses (RemoteServiceException). Tracking
    // foreground-only tetap jalan tanpa FGS.
    if (!await _fgsNotificationsOk()) return;
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

  /// Pastikan channel notifikasi FGS ada (flutter_background_service TIDAK
  /// membuat channel custom — hanya channel default bila channelId null).
  static Future<void> _ensureTrackingChannel() async {
    try {
      final impl = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (impl == null) return;
      // Android 13+: minta izin POST_NOTIFICATIONS agar notifikasi FGS
      // pasti bisa tampil (best-effort, dialog OS hanya muncul sekali).
      await impl.requestNotificationsPermission();
      // Importance.min + tanpa suara/getar: notifikasi FGS wajib ada
      // (ketentuan Android) tapi harus diam total — tracking bukan
      // peristiwa yang perlu mengganggu pengguna.
      await impl.createNotificationChannel(
        const AndroidNotificationChannel(
          kTrackingNotificationChannelId,
          'SBPS Tracking',
          description: 'Perekaman lokasi kerja saat presensi terbuka.',
          importance: Importance.min,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          showBadge: false,
        ),
      );
      // Hapus channel lama yang mungkin terbentuk dengan importance
      // default di perangkat yang sudah pernah menjalankan build lama.
      try {
        await impl.deleteNotificationChannel(channelId: _kOldTrackingChannelId);
      } catch (_) {}
    } catch (_) {
      // Best-effort — guard di startTracking menangani sisanya.
    }
  }

  /// true bila notifikasi FGS berpeluang sukses diposting: izin notifikasi
  /// aktif dan channel tracking ada & tidak diblokir user. Gagal verifikasi
  /// (isolate tanpa plugin) → true agar FGS tidak mati total.
  static Future<bool> _fgsNotificationsOk() async {
    try {
      final impl = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (impl == null) return true;
      if (await impl.areNotificationsEnabled() == false) return false;
      final channels = await impl.getNotificationChannels();
      final channel = channels
          ?.where((c) => c.id == kTrackingNotificationChannelId)
          .toList();
      if (channel == null || channel.isEmpty) return false;
      if (channel.first.importance == Importance.none) return false;
      return true;
    } catch (_) {
      return true;
    }
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

  /// Sama dengan konfigurasi server (interval_seconds=300).
  static const _gpsInterval = Duration(minutes: 5);

  static void _startGpsInterval(ServiceInstance service) {
    if (_isTracking) return;
    _isTracking = true;

    unawaited(pingOnce(service));

    _gpsTimer = Timer.periodic(_gpsInterval, (_) {
      unawaited(pingOnce(service));
    });
  }

  static void _stopGpsInterval(ServiceInstance service) {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    _isTracking = false;

    // Tidak memperbarui konten notifikasi di sini: invoke('update')
    // memicu posting ulang notifikasi FGS. Saat service berhenti,
    // notifikasinya hilang sendiri (stopSelf).
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

  /// Ambil satu titik GPS + append ke buffer Hive (timer service dan
  /// watchdog WorkManager).
  static Future<void> pingOnce(ServiceInstance? service) async {
    try {
      final location = LocationService();
      if (!await location.isServiceEnabled()) return;

      // While-in-use cukup: FGS tipe location di-start saat app foreground.
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }

      final position = await location.getCurrentPosition();
      if (position == null) return;

      await LocationBufferService.appendPointIsolate(
        lat: position.latitude,
        lng: position.longitude,
        timestamp: position.timestamp.toLocal(),
      );

      // Tidak memperbarui konten notifikasi tiap ping: invoke('update')
      // memicu posting ulang notifikasi FGS yang di sebagian perangkat
      // tampil sebagai notifikasi baru (heads-up + bunyi). Konten FGS
      // tetap statis "Merekam lokasi kerja...".

      // Await: isolate watchdog bisa mati sebelum upload selesai.
      await TrackingIsolateUpload.flush();
    } catch (_) {}
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
