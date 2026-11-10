import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_compression_service.dart';
import '../../core/push_token_service.dart';
import '../../core/watermark_service.dart';
import '../../features/auth/auth_providers.dart';

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

/// Ambil foto ber-watermark dari kamera.
Future<CapturedPhoto?> takeWatermarkedPhoto(
  WidgetRef ref, {
  double maxWidth = 1600,
  int imageQuality = 85,
}) async {
  XFile? picked;
  try {
    picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
  } on PlatformException catch (e) {
    _showCameraFeedback(e.code);
    return null;
  } catch (_) {
    _showCameraFeedback(null);
    return null;
  }
  if (picked == null) return null;

  try {
    String? employeeName;
    try {
      final userAsync = ref.read(authControllerProvider);
      userAsync.whenData((user) {
        if (user != null) {
          employeeName = user.name;
        }
      });
    } catch (_) {}

    final watermarkService = WatermarkService();
    final watermarkResult = await watermarkService.watermark(
      sourcePath: picked.path,
      employeeName: employeeName,
    );

    final compressor = PhotoCompressionService();
    final compressedPath = await compressor.compress(watermarkResult.path);

    return CapturedPhoto(
      path: compressedPath,
      gpsStatus: watermarkResult.gpsStatus,
      latitude: watermarkResult.latitude,
      longitude: watermarkResult.longitude,
    );
  } catch (_) {
    _showCameraFeedback('process_failed');
    return null;
  }
}

void _showCameraFeedback(String? code) {
  final message = switch (code) {
    'camera_access_denied' ||
    'camera_access_restricted' =>
      'Izin kamera ditolak. Aktifkan izin kamera di Pengaturan lalu coba lagi.',
    'process_failed' => 'Gagal memproses foto. Coba ambil ulang.',
    _ => 'Tidak dapat membuka kamera. Periksa izin kamera lalu coba lagi.',
  };
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}
