/// Titik kerja aktif dari GET /titik-aktif (docs/api-mobile.md §6.1).
/// Koordinat dipakai validasi radius check-in/check-out di backend.
class Titik {
  const Titik({
    required this.id,
    required this.nama,
    this.proyek,
    required this.latitude,
    required this.longitude,
    required this.radiusPresensiMeter,
  });

  final String id;
  final String nama;
  final String? proyek;
  final double latitude;
  final double longitude;
  final double radiusPresensiMeter;

  factory Titik.fromJson(Map<String, dynamic> json) => Titik(
        id: json['id']?.toString() ?? '',
        nama: json['nama']?.toString() ?? '',
        proyek: json['proyek']?.toString(),
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        radiusPresensiMeter:
            (json['radius_presensi_meter'] as num?)?.toDouble() ?? 0,
      );

  /// Parse toleran — null bila [raw] bukan objek titik yang valid.
  /// Dipakai untuk nested `titik` pada respons presensi.
  static Titik? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      return Titik.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }
}
