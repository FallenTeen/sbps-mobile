import 'package:intl/intl.dart';

/// Shared formatter untuk seluruh aplikasi.
/// Locale: id_ID (titik = ribuan, koma = desimal).

/// ──────────────────── ANGKA ────────────────────

/// Angka desimal: tampilkan bulat bila pecah, else 1 desimal.
String fmtNum(num? n) {
  if (n == null) return '-';
  if (n % 1 == 0) return n.toInt().toString();
  return n.toStringAsFixed(1);
}

/// Ribuan dengan titik gaya Indonesia: 1234567 -> 1.234.567.
String fmtRibuan(num n) {
  final negatif = n < 0;
  final s = n.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final sisa = s.length - i - 1;
    if (sisa > 0 && sisa % 3 == 0) buf.write('.');
  }
  return '${negatif ? '-' : ''}$buf';
}

/// Rupiah penuh: Rp 50.000.000.
String fmtRp(num n) => 'Rp ${fmtRibuan(n)}';

/// Rupiah ringkas untuk sumbu/label: 1,2 M / 50 jt / 500 rb.
String fmtRpCompact(num n) {
  final abs = n.abs().toDouble();
  String val(String unit, double d) =>
      '${n < 0 ? '-' : ''}${d % 1 == 0 ? d.toInt() : d.toStringAsFixed(1)} $unit';
  if (abs >= 1000000000) return val('M', abs / 1000000000);
  if (abs >= 1000000) return val('jt', abs / 1000000);
  if (abs >= 1000) return val('rb', abs / 1000);
  return fmtRp(n);
}

/// Label minggu dari tanggal ISO 'YYYY-MM-DD' -> 'D/M'.
String fmtMingguLabel(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  final d = int.tryParse(parts[2]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return '$d/$m';
}

const kBulanNama = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Ags',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// ──────────────────── TANGGAL & WAKTU ────────────────────

/// Parse input flexible: DateTime, ISO string, atau null.
DateTime? _parseDate(dynamic input) {
  if (input == null) return null;
  if (input is DateTime) return input;
  if (input is String) return DateTime.tryParse(input);
  return null;
}

/// Tanggal singkat: '10 Sep 2026'
String fmtTanggal(dynamic input) {
  final dt = _parseDate(input);
  if (dt == null) return '-';
  return DateFormat('d MMM yyyy', 'id_ID').format(dt);
}

/// Tanggal lengkap: '10 September 2026'
String fmtTanggalPanjang(dynamic input) {
  final dt = _parseDate(input);
  if (dt == null) return '-';
  return DateFormat('d MMMM yyyy', 'id_ID').format(dt);
}

/// Jam:menit 24h: '14:32'
String fmtWaktu(dynamic input) {
  final dt = _parseDate(input);
  if (dt == null) return '-';
  return DateFormat('HH:mm', 'id_ID').format(dt);
}

/// Gabungan tanggal + jam: '10 Sep 2026, 14:32'
String fmtTanggalWaktu(dynamic input) {
  final dt = _parseDate(input);
  if (dt == null) return '-';
  return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
}

/// Waktu relatif: 'Baru saja', '5 menit lalu', '2 jam lalu', 'Kemarin', '10 Sep 2026'
String fmtRelatif(dynamic input) {
  final dt = _parseDate(input);
  if (dt == null) return '-';
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.isNegative) return fmtTanggal(dt);
  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays == 1) return 'Kemarin';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return fmtTanggal(dt);
}

/// ──────────────────── SATUAN BISNIS ────────────────────

/// Angka + satuan km: '125.000 km'
String fmtKm(double? n) {
  if (n == null) return '-';
  return '${fmtRibuan(n)} km';
}

/// Angka + satuan liter: '45,5 L'
String fmtLiter(double? n) {
  if (n == null) return '-';
  final s = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);
  return '$s L';
}

/// Angka + satuan jam: '128,5 jam'
String fmtJam(double? n) {
  if (n == null) return '-';
  final s = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);
  return '$s jam';
}

/// Jumlah rit + satuan: '12 rit'
String fmtRitase(int? jumlah, [String satuan = 'rit']) {
  if (jumlah == null) return '-';
  return '$jumlah $satuan';
}
