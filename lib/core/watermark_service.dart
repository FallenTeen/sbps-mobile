import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'location_service.dart';

/// Status GPS saat foto diambil.
enum GpsStatus { available, unavailable }

/// Hasil watermarking foto.
class WatermarkResult {
  const WatermarkResult({
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

/// Service untuk membakar watermark (koordinat + timestamp + nama karyawan)
/// ke pixel foto sebelum kompresi.
///
/// Menggunakan package `image` untuk manipulasi pixel, bukan EXIF metadata.
class WatermarkService {
  WatermarkService({LocationService? locationService})
      : _locationService = locationService ?? LocationService();

  final LocationService _locationService;

  /// watermark foto di [sourcePath] dan simpan ke path baru.
  ///
  /// [employeeName] bersifat opsional — tampil kalau tidak null/kosong.
  /// GPS diambil dengan timeout; kalau gagal, watermark menampilkan
  /// "Lokasi tidak tersedia" dan GPS status = unavailable.
  Future<WatermarkResult> watermark({
    required String sourcePath,
    String? employeeName,
  }) async {
    // 1. Ambil GPS (dengan fallback).
    double? lat;
    double? lng;
    var gpsStatus = GpsStatus.unavailable;

    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        lat = position.latitude;
        lng = position.longitude;
        gpsStatus = GpsStatus.available;
      }
    } catch (_) {
      // GPS gagal — lanjut tanpa koordinat.
    }

    // 2. Baca gambar.
    final bytes = await File(sourcePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      // Gagal decode — kembalikan path asli.
      return WatermarkResult(
        path: sourcePath,
        gpsStatus: gpsStatus,
        latitude: lat,
        longitude: lng,
      );
    }

    // 3. Siapkan teks watermark.
    final now = DateTime.now();
    final timestamp = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);

    final lines = <String>[];
    if (lat != null && lng != null) {
      lines.add('${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}');
    } else {
      lines.add('Lokasi tidak tersedia');
    }
    lines.add(timestamp);
    if (employeeName != null && employeeName.isNotEmpty) {
      lines.add(employeeName);
    }

    // 4. Gambar watermark ke image.
    _drawWatermark(image, lines);

    // 5. Simpan hasil.
    final outBytes = img.encodeJpg(image, quality: 95);
    final outPath = sourcePath.replaceAll('.jpg', '_wm.jpg');
    await File(outPath).writeAsBytes(outBytes);

    return WatermarkResult(
      path: outPath,
      gpsStatus: gpsStatus,
      latitude: lat,
      longitude: lng,
    );
  }

  /// Gambar watermark di pojok bawah gambar dengan background semi-transparan.
  void _drawWatermark(img.Image image, List<String> lines) {
    const fontSize = 24;
    const padding = 12;
    const lineHeight = 30;

    // Hitung ukuran bounding box.
    final maxLineWidth = lines.fold<int>(0, (max, line) {
      final w = line.length * (fontSize * 6) ~/ 10;
      return w > max ? w : max;
    });
    final boxWidth = maxLineWidth + padding * 2;
    final boxHeight = lines.length * lineHeight + padding * 2;

    // Posisi pojok bawah.
    final boxX = image.width - boxWidth - 16;
    final boxY = image.height - boxHeight - 16;

    // Gambar background semi-transparan (gelap).
    img.fillRect(
      image,
      x1: boxX,
      y1: boxY,
      x2: boxX + boxWidth,
      y2: boxY + boxHeight,
      color: img.ColorRgba8(0, 0, 0, 160),
    );

    // Gambar teks per baris.
    final font = img.arial24;
    for (var i = 0; i < lines.length; i++) {
      img.drawString(
        image,
        lines[i],
        x: boxX + padding,
        y: boxY + padding + i * lineHeight,
        font: font,
        color: img.ColorRgb8(255, 255, 255),
      );
    }
  }
}
