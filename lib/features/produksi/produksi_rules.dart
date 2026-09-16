import 'models/production_session.dart';

/// Logika bisnis murni modul Produksi (Phase 13).
/// Tidak mengubah formula/validasi backend — hanya membungkus aturan
/// yang sudah ada menjadi fungsi teruji supaya bisa dipakai ulang UI.

/// Format durasi sesi ringkas: `45m`, `1j 30m`, `2j`.
String formatDurasiSesi(Duration d) {
  if (d.inHours > 0) {
    final sisa = d.inMinutes.remainder(60);
    return sisa == 0 ? '${d.inHours}j' : '${d.inHours}j ${sisa}m';
  }
  return '${d.inMinutes}m';
}

/// Ringkasan "Produksi Hari Ini" di home sesi produksi — dihitung
/// murni dari data yang sudah tersedia di endpoint yang ada:
/// - total sesi hari ini  = sesi selesai (titik-progress) + sesi berjalan;
/// - total output hari ini = jumlah total_output dari titik-progress;
/// - sesi berjalan         = daftar /sesi-aktif;
/// - sesi menunggu QC      = jumlah sample `menunggu_hasil` milik sesi user.
///
/// Endpoint `/produksi/stats` tidak tersedia, sehingga agregasi dihitung
/// dari data sesi-aktif + titik-progress + waitingQC yang sudah ada.
class ProduksiHomeSummary {
  const ProduksiHomeSummary({
    required this.totalSesi,
    required this.totalOutput,
    required this.sesiBerjalan,
    required this.sesiMenungguQc,
  });

  final int totalSesi;
  final double totalOutput;
  final int sesiBerjalan;

  /// Sample yang masih menunggu hasil uji tekan (dari QC).
  final int sesiMenungguQc;

  /// Sesi yang butuh perhatian = sesi berjalan yang sudah menunggu hasil
  /// uji tekan (QC-nya tertahan).
  int get butuhPerhatian => sesiMenungguQc;
}

ProduksiHomeSummary produksiHomeSummary({
  List<ProductionSession> sesiAktif = const [],
  List<TitikProgressItem> progress = const [],
  int waitingQcCount = 0,
}) {
  final totalOutput = progress.fold<double>(
    0,
    (sum, item) => sum + item.totalOutput,
  );
  final sesiSelesai = progress.fold<int>(
    0,
    (sum, item) => sum + item.jumlahSesi,
  );
  return ProduksiHomeSummary(
    totalSesi: sesiSelesai + sesiAktif.length,
    totalOutput: totalOutput,
    sesiBerjalan: sesiAktif.length,
    sesiMenungguQc: waitingQcCount,
  );
}

/// Filter status riwayat secara client-side (backend tidak menyediakan
/// param status). `null`/`Semua` = tanpa filter.
List<ProductionSession> filterRiwayatByStatus(
  List<ProductionSession> items,
  String? status,
) {
  if (status == null || status.isEmpty || status == 'Semua') return items;
  if (status == 'Berjalan') return items.where((s) => s.berjalan).toList();
  if (status == 'Selesai') return items.where((s) => !s.berjalan).toList();
  return items;
}

/// Validasi inline hasil output — satu-satunya aturan: angka valid &
/// tidak negatif (sama dengan validasi `_SelesaikanSheet` Fase 2).
String? validateHasilOutput(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return 'Hasil output wajib diisi.';
  final n = double.tryParse(text);
  if (n == null) return 'Masukkan angka yang valid.';
  if (n < 0) return 'Tidak boleh negatif.';
  return null;
}

/// Parafrase status sesi dari raw backend.
String sessionStatusLabel(String status) =>
    status == 'selesai' ? 'Selesai' : 'Berjalan';

/// "Next action" sebuah sesi aktif — turunan data yang tersedia:
/// bila sudah ada sample menunggu hasil uji tekan, langkah berikutnya
/// adalah mencatat hasil uji tekan; bila belum, catat slump test berkala.
String nextActionForSession({required bool hasWaitingQc}) => hasWaitingQc
    ? 'Catat hasil uji tekan (QC menunggu hasil)'
    : 'Catat slump test berkala';