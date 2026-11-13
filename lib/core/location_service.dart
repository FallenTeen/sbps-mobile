import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Wrapper geolocator: izin lokasi + posisi saat ini.
class LocationService {
  /// True bila izin when-in-use (atau always) sudah diberikan.
  Future<bool> ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Minta upgrade izin ke ALWAYS (dialog "Allow all the time").
  /// Return false bila user menolak / masih while-in-use.
  Future<bool> ensureAlwaysPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!await ensurePermission()) return false;
      permission = await Geolocator.checkPermission();
    }
    if (permission == LocationPermission.always) return true;

    // Upgrade while-in-use -> always (geolocator menampilkan dialog ke-2).
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always;
  }

  /// True bila izin ALWAYS sudah siap untuk background tracking.
  Future<bool> hasAlwaysPermission() async =>
      await Geolocator.checkPermission() == LocationPermission.always;

  /// Izin lokasi saat ini tanpa memicu dialog.
  Future<LocationPermission> currentPermission() =>
      Geolocator.checkPermission();

  /// Buka settings inbox (fallback bila deniedForever).
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<void> openSettings() => Geolocator.openLocationSettings();

  /// Null = GPS mati / izin ditolak (caller menampilkan state penjelasan).
  Future<Position?> getCurrentPosition() async {
    if (!await isServiceEnabled()) return null;
    if (!await ensurePermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } on TimeoutException {
      // Posisi lambat didapat (GPS cold start) — ulangi dengan akurasi rendah.
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
    }
  }

  double distanceMeters({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng);
  }
}
