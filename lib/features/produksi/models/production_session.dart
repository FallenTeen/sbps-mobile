import '../../../core/json_num.dart';

/// Sesi produksi — struktur `data` dari /produksi/mulai, /selesai,
/// /sesi-aktif, dan item /riwayat (docs/api-mobile.md §8).
class ProductionSession {
  const ProductionSession({
    required this.id,
    this.mesinId,
    this.mesinNama,
    this.produkId,
    this.produkNama,
    this.satuanOutput,
    this.titikId,
    this.titikNama,
    this.mulai,
    this.selesai,
    this.hasilOutput = 0,
    this.status = 'berjalan',
    this.catatan,
  });

  final String id;
  final String? mesinId;
  final String? mesinNama;
  final String? produkId;
  final String? produkNama;
  final String? satuanOutput;
  final String? titikId;
  final String? titikNama;
  final DateTime? mulai;
  final DateTime? selesai;
  final double hasilOutput;
  final String status;
  final String? catatan;

  bool get berjalan => status == 'berjalan';

  factory ProductionSession.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? sub(Object? raw) =>
        raw is Map ? Map<String, dynamic>.from(raw) : null;
    final mesin = sub(json['mesin']);
    final produk = sub(json['produk']);
    final titik = sub(json['titik']);
    return ProductionSession(
      id: json['id']?.toString() ?? '',
      mesinId: mesin?['id']?.toString(),
      mesinNama: mesin?['nama']?.toString(),
      produkId: produk?['id']?.toString(),
      produkNama: produk?['nama']?.toString(),
      satuanOutput: produk?['satuan_output']?.toString(),
      titikId: titik?['id']?.toString(),
      titikNama: titik?['nama']?.toString(),
      mulai: _parseDate(json['mulai']),
      selesai: _parseDate(json['selesai']),
      hasilOutput: parseNum(json['hasil_output']) ?? 0,
      status: json['status']?.toString() ?? 'berjalan',
      catatan: json['catatan']?.toString(),
    );
  }

  static DateTime? _parseDate(Object? raw) =>
      raw == null || raw.toString().isEmpty
      ? null
      : DateTime.tryParse(raw.toString());
}

/// Item ringkasan GET /produksi/titik-progress.
class TitikProgressItem {
  const TitikProgressItem({
    required this.titikId,
    this.titikNama,
    this.totalOutput = 0,
    this.jumlahSesi = 0,
  });

  final String titikId;
  final String? titikNama;
  final double totalOutput;
  final int jumlahSesi;

  factory TitikProgressItem.fromJson(Map<String, dynamic> json) {
    return TitikProgressItem(
      titikId: json['titik_id']?.toString() ?? '',
      titikNama: json['titik']?.toString(),
      totalOutput: parseNum(json['total_output']) ?? 0,
      jumlahSesi: parseInt(json['jumlah_sesi']) ?? 0,
    );
  }
}

/// Halaman riwayat produksi (`{ items, pagination }`).
class ProduksiRiwayatPage {
  const ProduksiRiwayatPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<ProductionSession> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static ProduksiRiwayatPage fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = raw is Map ? (raw['items'] as List? ?? const []) : const [];
    final pag = map['pagination'];
    final pagMap = pag is Map ? Map<String, dynamic>.from(pag) : const {};
    return ProduksiRiwayatPage(
      items: [
        for (final e in list)
          ProductionSession.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      currentPage: parseInt(pagMap['current_page']) ?? 1,
      lastPage: parseInt(pagMap['last_page']) ?? 1,
      total: parseInt(pagMap['total']) ?? 0,
    );
  }
}
