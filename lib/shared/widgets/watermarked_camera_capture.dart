import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_compression_service.dart';
import '../../core/watermark_service.dart';
import '../auth/auth_providers.dart';

/// Hasil capture foto ber-watermark + terkompresi.
class CapturedPhoto {
  const CapturedPhoto({
    required this.path,
    required this.gpsStatus,
    required this.latitude,
    required this.longitude,
  });

  final String path;
  final GpsStatus gpsStatus;
  final double? latitude;
  final double? longitude;
}

/// Service reusable untuk ambil foto dari kamera, tambahkan watermark
/// (koordinat + timestamp + nama karyawan), lalu kompres.
///
/// Digunakan di: Presensi, Formulir, Dokumentasi, Helper Presensi,
/// Checklist Armada, Servis Armada.
///
/// Flow: camera → watermark → compress → return path.
class WatermarkedCameraCapture {
  WatermarkedCameraCapture({
    required WidgetRef ref,
    int maxWidth = 1600,
    int imageQuality = 85,
  })  : _ref = ref,
        _maxWidth = maxWidth,
        _imageQuality = imageQuality;

  final WidgetRef _ref;
  final int _maxWidth;
  final int _imageQuality;

  /// Ambil foto dari kamera, beri watermark, kompres, dan kembalikan hasilnya.
  ///
  /// Mengembalikan null jika user membatalkan (tidak memilih foto).
  Future<CapturedPhoto?> capture() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: _maxWidth,
      imageQuality: _imageQuality,
    );
    if (picked == null) return null;

    // Ambil nama karyawan dari user profile (opsional).
    String? employeeName;
    try {
      final userAsync = _ref.read(currentUserProvider);
      userAsync.whenData((user) {
        if (user != null && user.hasKaryawan) {
          employeeName = user.name;
        } else if (user != null) {
          employeeName = user.name;
        }
      });
    } catch (_) {
      // User info tidak tersedia — watermark tanpa nama.
    }

    // Watermark (koordinat + timestamp + nama).
    final watermarkService = WatermarkService();
    final watermarkResult = await watermarkService.watermark(
      sourcePath: picked.path,
      employeeName: employeeName,
    );

    // Kompres.
    final compressor = PhotoCompressionService();
    final compressedPath = await compressor.compress(watermarkResult.path);

    return CapturedPhoto(
      path: compressedPath,
      gpsStatus: watermarkResult.gpsStatus,
      latitude: watermarkResult.latitude,
      longitude: watermarkResult.longitude,
    );
  }
}

/// Extension untuk memudahkan penggunaan di ConsumerState/ConsumerWidget.
extension WatermarkedCameraCaptureExt on ConsumerState {
  /// Ambil foto ber-watermark dari kamera.
  Future<CapturedPhoto?> takeWatermarkedPhoto({
    int maxWidth = 1600,
    int imageQuality = 85,
  }) {
    final capture = WatermarkedCameraCapture(
      ref: ref,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    return capture.capture();
  }
}
