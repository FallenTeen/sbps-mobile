/// Satu entri Formulir Lapangan (docs/api-mobile.md §7).
class FormulirLapangan {
  const FormulirLapangan({
    required this.id,
    this.presensiId,
    this.tanggal,
    this.titik,
    this.aktivitasDilakukan,
    this.kondisiArea,
    this.kendala,
    this.catatanTambahan,
    this.foto = const [],
  });

  final String id;
  final String? presensiId;
  final String? tanggal;

  /// Backend mengirim nama titik sebagai string.
  final String? titik;
  final String? aktivitasDilakukan;
  final String? kondisiArea;
  final String? kendala;
  final String? catatanTambahan;
  final List<String> foto;

  static FormulirLapangan fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('formulir tidak valid');
    final json = Map<String, dynamic>.from(raw);
    return FormulirLapangan(
      id: json['id']?.toString() ?? '',
      presensiId: json['presensi_id']?.toString(),
      tanggal: json['tanggal']?.toString(),
      titik: json['titik']?.toString(),
      aktivitasDilakukan: json['aktivitas_dilakukan']?.toString(),
      kondisiArea: json['kondisi_area']?.toString(),
      kendala: json['kendala']?.toString(),
      catatanTambahan: json['catatan_tambahan']?.toString(),
      foto:
          (json['foto'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

/// Halaman riwayat formulir.
class RiwayatFormulirPage {
  const RiwayatFormulirPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<FormulirLapangan> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  static RiwayatFormulirPage fromJson(Object? raw) {
    if (raw is! Map) {
      return const RiwayatFormulirPage(items: [], currentPage: 1, lastPage: 1);
    }
    final json = Map<String, dynamic>.from(raw);
    final pagination = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : <String, dynamic>{};
    final itemsRaw = json['items'];
    return RiwayatFormulirPage(
      items: itemsRaw is List
          ? itemsRaw.map(FormulirLapangan.fromJson).toList()
          : [],
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagination['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}
