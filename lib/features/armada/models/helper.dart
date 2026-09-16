/// Model helper armada — helper tidak punya akun, PIC (Driver)
/// yang mengabsenkan mereka dari aplikasinya.
/// (docs manual-book Section 21)
library;

/// Helper yang ditugaskan ke armada milik PIC aktif.
class Helper {
  const Helper({
    required this.id,
    required this.nama,
    this.fotoUrl,
    this.statusHariIni,
  });

  final String id;
  final String nama;
  final String? fotoUrl;

  /// Status presensi hari ini: null = belum ada, 'check_in', 'check_out'.
  final String? statusHariIni;

  bool get sudahCheckIn =>
      statusHariIni == 'check_in' || statusHariIni == 'check_out';
  bool get sudahCheckOut => statusHariIni == 'check_out';

  /// Label status presensi hari ini untuk user.
  String get statusHariIniLabel => switch (statusHariIni) {
    'check_in' => 'Sedang Bekerja',
    'check_out' => 'Sudah Pulang',
    _ => 'Belum Masuk',
  };

  /// Aksi berikutnya untuk helper: presensi masuk (belum) / pulang (bekerja).
  /// Null saat sudah pulang (tidak ada aksi lagi hari ini).
  String? get nextActionLabel => switch (statusHariIni) {
    'check_in' => 'Presensi Pulang',
    _ => sudahCheckOut ? null : 'Presensi Masuk',
  };

  factory Helper.fromJson(Map<String, dynamic> json) {
    return Helper(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      fotoUrl: json['foto_url']?.toString(),
      statusHariIni: json['status_hari_ini']?.toString(),
    );
  }
}
