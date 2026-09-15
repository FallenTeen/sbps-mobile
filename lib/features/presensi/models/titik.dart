/// Titik kerja aktif dari GET /titik-aktif atau GET /titik-map (docs/api-mobile.md).
/// Koordinat dipakai validasi radius check-in/check-out di backend dan peta interaktif.
class Titik {
  const Titik({
    required this.id,
    required this.nama,
    this.proyek,
    this.proyekId,
    this.proyekNama,
    this.status,
    required this.latitude,
    required this.longitude,
    required this.radiusPresensiMeter,
  });

  final String id;
  final String nama;
  final String? proyek;
  final String? proyekId;
  final String? proyekNama;
  final String? status;
  final double latitude;
  final double longitude;
  final double radiusPresensiMeter;

  /// Label proyek untuk tampilan UI.
  String? get displayProyek =>
      (proyekNama != null && proyekNama!.isNotEmpty) ? proyekNama : proyek;

  /// Validasi apakah koordinat titik valid untuk dipetakan.
  bool get hasValidCoordinates =>
      latitude != 0 &&
      longitude != 0 &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  factory Titik.fromJson(Map<String, dynamic> json) => Titik(
    id: json['id']?.toString() ?? json['titik_id']?.toString() ?? '',
    nama: json['nama']?.toString() ?? json['titik']?.toString() ?? '',
    proyek: json['proyek']?.toString() ?? json['proyek_nama']?.toString(),
    proyekId: json['proyek_id']?.toString(),
    proyekNama: json['proyek_nama']?.toString() ?? json['proyek']?.toString(),
    status: json['status']?.toString(),
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
