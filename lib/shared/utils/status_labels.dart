// Label status & peran yang ramah user (PERBAIKAN PHASE 18).
//
// Istilah resmi mengikuti docs/api-mobile.md backend; wire-value dari
// server (snake_case/underscore/uppercase) tidak boleh ditampilkan
// mentah ke user.

const Map<String, String> _kStatusLabels = {
  'aktif': 'Aktif',
  'berjalan': 'Berjalan',
  'selesai': 'Selesai',
  'dibatalkan': 'Dibatalkan',
  'pending': 'Pending',
  'lunas': 'Lunas',
  'belum_dibayar': 'Belum Dibayar',
  'dibayar': 'Dibayar',
  'jatuh_tempo': 'Jatuh Tempo',
  'diterima': 'Diterima',
  'ditolak': 'Ditolak',
  'diajukan': 'Diajukan',
  'draft': 'Draft',
};

/// Ubah status wire-value menjadi label human-friendly (title case,
/// underscore diganti spasi). Nilai tak dikenal di-render huruf kapital.
String statusLabel(String status) {
  final lower = status.trim().toLowerCase();
  if (lower.isEmpty) return '-';
  return _kStatusLabels[lower] ?? titleCase(lower);
}

/// Label status proyek kontrak & invoice kontraktor (portal kontraktor).
String kontraktorStatusLabel(String status) => statusLabel(status);

/// Label peran pengirim chat/komunikasi kontraktor.
String kontraktorParticipantLabel(String role) {
  final lower = role.trim().toLowerCase();
  return switch (lower) {
    'kontraktor' => 'Kontraktor',
    'owner' => 'Owner',
    'admin keuangan' => 'Admin Keuangan',
    _ => lower.isEmpty ? '-' : titleCase(lower),
  };
}

/// Ubah teks apa pun (snake_case) menjadi Title Case.
String titleCase(String value) {
  final words = value
      .trim()
      .toLowerCase()
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '-';
  return words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}