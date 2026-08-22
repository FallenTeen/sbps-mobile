/// Penugasan titik ke user dari GET /assignments (docs/api-mobile.md §5.6).
class Assignment {
  const Assignment({
    required this.id,
    required this.titikId,
    this.titik,
    this.proyek,
    required this.status,
    this.tanggalMulai,
    this.tanggalSelesai,
  });

  final String id;
  final String titikId;
  final String? titik;
  final String? proyek;
  final String status;
  final String? tanggalMulai;
  final String? tanggalSelesai;

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id']?.toString() ?? '',
        titikId: json['titik_id']?.toString() ?? '',
        titik: json['titik']?.toString(),
        proyek: json['proyek']?.toString(),
        status: json['status']?.toString() ?? '',
        tanggalMulai: json['tanggal_mulai']?.toString(),
        tanggalSelesai: json['tanggal_selesai']?.toString(),
      );
}
