import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'background_location_service.dart';
import 'location_buffer_service.dart';

const kTrackingRestartTask = 'tracking-restart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kTrackingRestartTask) {
      await TrackingWatchdog.runOnce();
    }
    return Future.value(true);
  });
}

/// Watchdog Android: hidupkan ulang perekaman GPS tiap ~15 menit saat
/// presensi terbuka. Callback berjalan di isolate terpisah (Hive di-init
/// di sini, tanpa platform channel).
class TrackingWatchdog {
  TrackingWatchdog._();

  static bool _initialized = false;

  /// Idempotent, Android only. Gagal registrasi tidak memblokir tracking.
  static Future<void> ensureRegistered() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (!_initialized) {
        await Workmanager().initialize(callbackDispatcher);
        _initialized = true;
      }
      await Workmanager().registerPeriodicTask(
        kTrackingRestartTask,
        kTrackingRestartTask,
        frequency: const Duration(minutes: 15),
      );
    } catch (_) {
      // Watchdog best-effort.
    }
  }

  static Future<void> runOnce() async {
    try {
      DartPluginRegistrant.ensureInitialized();
      WidgetsFlutterBinding.ensureInitialized();
      await Hive.initFlutter();

      // Dua guard privasi sebelum merestart FGS:
      // 1. tracking_desired = false → user sudah checkout atau belum checkin.
      // 2. getPresensiOpenCached() memvalidasi tanggal — cache dari hari
      //    sebelumnya ditolak sehingga watchdog tidak merestart tracking
      //    di luar jam kerja meskipun app tidak dibuka semalaman.
      if (!await LocationBufferService.isTrackingDesired()) return;
      if (!await LocationBufferService.getPresensiOpenCached()) return;

      try {
        await BackgroundLocationService.instance.startTracking();
      } catch (_) {}
      await BackgroundLocationService.pingOnce(null);
    } catch (_) {}
  }
}
