/// Helper format angka & Rupiah untuk dashboard (tanpa dependency intl).
library;

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
