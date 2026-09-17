/// Sample QC (slump test / uji tekan) — docs/api-mobile.md §10.
///
/// Bentuk `produksi` berbeda antar endpoint: respons slump/uji-tekan
/// memakai string, detail QC memakai string juga, sedangkan item riwayat
/// memakai objek `session` berisi {produk, mesin, titik} sebagai map.
/// Parser ini menoleransi kedua bentuk.
class QcSample {
  const QcSample({
    required this.id,
    required this.jenisUji,
    required this.status,
    this.nilaiSlump,
    this.hasilUjiTekan,
    this.tanggalUjiTekanRencana,
    this.catatan,
    this.createdAt,
    this.updatedAt,
    this.sessionId,
    this.produkNama,
    this.mesinNama,
    this.titikNama,
    this.operatorNama,
    this.sesiMulai,
    this.sesiSelesai,
  });

  final String id;
  final String jenisUji;
  final String status;
  final double? nilaiSlump;
  final double? hasilUjiTekan;

  /// Tanggal rencana uji tekan (YYYY-MM-DD).
  final String? tanggalUjiTekanRencana;
  final String? catatan;
  final DateTime? createdAt;

  /// Waktu perubahan status terakhir (hasil uji tekan direkam).
  /// Opsional — digunakan sebagai tanggal "selesai" sampel bila ada.
  final DateTime? updatedAt;

  final String? sessionId;
  final String? produkNama;
  final String? mesinNama;
  final String? titikNama;
  final String? operatorNama;
  final DateTime? sesiMulai;
  final DateTime? sesiSelesai;

  bool get menungguHasil => status == 'menunggu_hasil';
  bool get lolos => status == 'lolos';

  factory QcSample.fromJson(Map<String, dynamic> json) {
    String? namaOf(Object? raw) => raw == null
        ? null
        : raw is Map
        ? raw['nama']?.toString()
        : raw.toString();

    Map<String, dynamic>? sub(Object? raw) =>
        raw is Map ? Map<String, dynamic>.from(raw) : null;

    final produksi = sub(json['produksi']);
    final session = sub(json['session']);

    DateTime? parseDt(Object? raw) => raw == null || raw.toString().isEmpty
        ? null
        : DateTime.tryParse(raw.toString());

    // sessionId bisa dari produksi.session_id atau session.id.
    final sid =
        produksi?['session_id']?.toString() ?? session?['id']?.toString();

    return QcSample(
      id: json['id']?.toString() ?? '',
      jenisUji: json['jenis_uji']?.toString() ?? 'slump_test',
      status: json['status']?.toString() ?? '',
      nilaiSlump: (json['nilai_slump'] as num?)?.toDouble(),
      hasilUjiTekan: (json['hasil_uji_tekan'] as num?)?.toDouble(),
      tanggalUjiTekanRencana: json['tanggal_uji_tekan_rencana']?.toString(),
      catatan: json['catatan']?.toString(),
      createdAt: parseDt(json['created_at']),
      updatedAt: parseDt(json['updated_at']),
      sessionId: (sid == null || sid.isEmpty) ? null : sid,
      produkNama: namaOf(produksi?['produk']) ?? namaOf(session?['produk']),
      mesinNama: namaOf(produksi?['mesin']) ?? namaOf(session?['mesin']),
      titikNama: namaOf(produksi?['titik']) ?? namaOf(session?['titik']),
      operatorNama: produksi?['operator']?.toString(),
      sesiMulai: parseDt(produksi?['mulai']) ?? parseDt(session?['mulai']),
      sesiSelesai: parseDt(produksi?['selesai']) ?? parseDt(session?['selesai']),
    );
  }
}

/// Halaman riwayat QC (`{ items, pagination }`).
class QcRiwayatPage {
  const QcRiwayatPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<QcSample> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static QcRiwayatPage fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    final pag = map['pagination'];
    final pagMap = pag is Map ? Map<String, dynamic>.from(pag) : const {};
    return QcRiwayatPage(
      items: [
        if (list is List)
          for (final e in list)
            QcSample.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      currentPage: (pagMap['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagMap['last_page'] as num?)?.toInt() ?? 1,
      total: (pagMap['total'] as num?)?.toInt() ?? 0,
    );
  }
}
