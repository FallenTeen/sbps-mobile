import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Wrapper geolocator: izin lokasi + posisi saat ini.
/// Dipakai Fase A1.3 (jarak ke titik) dan A1.4 (payload check-in/out).
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

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<void> openSettings() => Geolocator.openLocationSettings();

  /// Null berarti GPS mati / izin ditolak — caller menampilkan state
  /// penjelasan, bukan error generik.
  Future<Position?> getCurrentPosition() async {
    if (!await isServiceEnabled()) return null;
    if (!await ensurePermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } on TimeoutException {
      // Posisi lambat didapat (GPS cold start) — ulangi dengan akurasi rendah.
      return Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
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
