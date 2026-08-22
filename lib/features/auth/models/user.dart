/// Model user dari GET /user — per audit (api-audit-report.md §4.1), objek
/// user dikembalikan LANGSUNG sebagai `data`, bukan dibungkus `data.user`.
/// Field `karyawan` ada di root objek; nilainya null berarti akun belum
/// terhubung ke data karyawan (prasyarat presensi/formulir/produksi/tracking).
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.jabatan,
    this.divisi,
    this.roles = const [],
    this.permissions = const [],
    this.karyawan,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? jabatan;
  final String? divisi;
  final List<String> roles;
  final List<String> permissions;

  /// Null = belum terhubung ke data karyawan.
  final Map<String, dynamic>? karyawan;

  bool get hasKaryawan => karyawan != null && karyawan!.isNotEmpty;

  bool hasRole(String role) => roles.contains(role);

  factory User.fromJson(Map<String, dynamic> json) {
    List<String> stringList(Object? raw) =>
        raw is List ? raw.map((e) => e.toString()).toList() : const [];

    return User(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? json['nama_lengkap'])?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      jabatan: json['jabatan']?.toString(),
      divisi: json['divisi']?.toString(),
      roles: stringList(json['roles']),
      permissions: stringList(json['permissions']),
      karyawan: json['karyawan'] is Map<String, dynamic>
          ? json['karyawan'] as Map<String, dynamic>
          : null,
    );
  }
}
