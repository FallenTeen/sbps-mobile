import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Fase unggahan yang bisa ditampilkan di UI thumbnail.
enum UploadPhase { compressing, sending }

/// Pipeline kompresi foto bersama untuk check-in, check-out, dan formulir
/// (Fase A1.6).
///
/// - Target ukuran maksimum ~500 KB.
/// - Sisi terpanjang di-resize maks [maxDim] px bila perlu.
/// - EXIF dipertahankan (`keepExif`) supaya orientasi foto tidak berbalik.
/// - Hasil disimpan sebagai file JPEG baru di direktori temporary aplikasi;
///   path file itulah yang masuk ke PendingAction — bukan bytes/base64.
///
/// Bila kompresi gagal (plugin error dsb.), path ASLI dikembalikan agar
/// alur presensi user tidak pernah terblokir oleh masalah kompresi.
class PhotoCompressionService {
  static const int maxDim = 1600;
  static const int targetBytes = 500 * 1024;

  Future<String> compress(String sourcePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final outPath = p.join(
        dir.path,
        'outbox_${stamp}_${p.basenameWithoutExtension(sourcePath)}.jpg',
      );

      var quality = 85;
      var bound = maxDim;
      String? best;

      // Turunkan kualitas bertahap sampai target; perkecil sisi bila
      // kualitas mentok rendah namun masih jauh dari target.
      while (quality >= 30) {
        final result = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          outPath,
          quality: quality,
          minWidth: bound,
          minHeight: bound,
          format: CompressFormat.jpeg,
          keepExif: true,
        );
        if (result == null) break;
        best = result.path;

        final size = await File(result.path).length();
        if (size <= targetBytes) return result.path;

        quality -= 15;
        if (quality < 45 && bound > 800) bound = 800;
      }

      // Kualitas terendah pun tetap lebih baik daripada file asli —
      // pakai hasil kompresi terakhir bila target tidak tercapai.
      return best ?? sourcePath;
    } catch (_) {
      // Kompresi tidak boleh menggagalkan presensi — pakai file asli.
      return sourcePath;
    }
  }
}
