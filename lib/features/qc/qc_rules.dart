import 'models/qc_sample.dart';

/// Logika bisnis murni modul QC (Phase 14) — queue-first inspection.
/// Tidak mengubah formula atau validasi backend; hanya membungkus aturan
/// yang sudah ada menjadi fungsi teruji supaya bisa dipakai ulang UI.

/// true jika [dt] berada di hari yang sama dengan [now].
bool isTodayFor(DateTime? dt, DateTime now) {
  if (dt == null) return false;
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

/// Sampel yang sedang menunggu pemeriksaan (belum ada hasil uji tekan).
bool qcMenunggu(QcSample s) => s.status == 'menunggu_hasil';

/// Sampel sudah punya keputusan hasil (terminal).
bool qcTerminal(QcSample s) => s.status == 'lolos' || s.status == 'tidak_lolos';

/// Waktu sampel mendapat hasil. Pakai `updated_at` bila tersedia
/// (backend mencatat kapan hasil uji tekan direkam), fallback `created_at`.
DateTime? qcWaktuSelesai(QcSample s) => s.updatedAt ?? s.createdAt;

/// Label jenis uji dari nilai backend.
String qcJenisUjiLabel(String jenisUji) =>
    jenisUji == 'uji_tekan' ? 'Uji Tekan' : 'Slump Test';

/// Sampel yang BENAR-BENAR selesai HARI INI: status terminal DAN tanggal
/// waktu selesainya == hari ini. Filter tanggal murni (bukan jumlah total).
List<QcSample> qcSelesaiHariIni(List<QcSample> items, DateTime now) {
  return items
      .where((s) => qcTerminal(s) && isTodayFor(qcWaktuSelesai(s), now))
      .toList();
}

/// Ringkasan home QC — angka jujur dari data server:
/// - menungguPemeriksaan = total sampel status `menunggu_hasil`
///   (langsung dari pagination server, jadi exact);
/// - selesaiHariIni = jumlah sampel yang benar-benar selesai hari ini
///   (filter tanggal murni).
class QcHomeSummary {
  const QcHomeSummary({
    required this.menungguPemeriksaan,
    required this.selesaiHariIni,
  });

  final int menungguPemeriksaan;
  final int selesaiHariIni;
}

QcHomeSummary qcHomeSummary({
  required int menungguPemeriksaan,
  required int selesaiHariIni,
}) => QcHomeSummary(
  menungguPemeriksaan: menungguPemeriksaan,
  selesaiHariIni: selesaiHariIni,
);

/// Validasi nilai angka WAJIB (actual/nilai slump/uji tekan).
/// Sesuai kontrak: angka valid, tidak kosong, tidak negatif.
String? validateNilaiWajib(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return 'Wajib diisi.';
  final n = double.tryParse(text);
  if (n == null) return 'Masukkan angka yang valid.';
  if (n < 0) return 'Tidak boleh negatif.';
  return null;
}

/// Validasi nilai angka OPSIONAL (target MPa). Kosong diperbolehkan.
String? validateNilaiOpsional(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  final n = double.tryParse(text);
  if (n == null) return 'Angka tidak valid.';
  if (n < 0) return 'Tidak boleh negatif.';
  return null;
}

/// Parafrase hasil yang TIDAK menghitung formula kelulusan (backend yang
/// menentukan). Hanya menjelaskan secara jujur apa yang akan direkam.
String qcResultNote({double? target, double? actual, String? satuan}) {
  final u = satuan ?? 'MPa';
  if (target == null) {
    return actual == null
        ? 'Hasil akan direkam. Status kelulusan ditentukan sistem.'
        : 'Actual $actual $u direkam. Status kelulusan ditentukan sistem.';
  }
  return actual == null
      ? 'Actual akan dibandingkan dengan target $target $u oleh sistem.'
      : 'Actual $actual $u dicatat terhadap target $target $u. '
            'Status lolos/tidak lolos dihitung sistem (formula QC).';
}