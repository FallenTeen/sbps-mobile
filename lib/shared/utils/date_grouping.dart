import '../../core/formatters.dart';

/// Pengelompokan tanggal untuk daftar kronologis (pola NotifikasiScreen /
/// Riwayat Inventory): Hari Ini / Kemarin / Minggu Ini / tanggal penuh.
///
/// Dipakai sebagai header group dalam list agar user bisa memahami skala
/// waktu tanpa membaca setiap tanggal. Jangan duplikasi logika ini di layar
/// lain — pakai fungsi ini supaya perilakunya konsisten.
String dateGroupLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(that).inDays;
  if (diff <= 0) return 'Hari Ini';
  if (diff == 1) return 'Kemarin';
  if (diff < 7) return 'Minggu Ini';
  return fmtTanggal(dt);
}