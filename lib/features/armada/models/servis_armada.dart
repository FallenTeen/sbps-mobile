/// Model Servis Armada — alur 4 bagian pengajuan, persetujuan, workshop, sparepart.
/// (docs manual-book Section 21 & api-mobile)
library;

/// Model Master Armada untuk dropdown pilihan unit saat pengajuan servis.
class MasterArmada {
  const MasterArmada({
    required this.id,
    required this.platNomor,
    this.kodeUnit,
    this.jenis,
    this.status,
  });

  final String id;
  final String platNomor;
  final String? kodeUnit;
  final String? jenis;
  final String? status;

  factory MasterArmada.fromJson(Map<String, dynamic> json) {
    return MasterArmada(
      id: json['id']?.toString() ?? '',
      platNomor: json['plat_nomor']?.toString() ?? '',
      kodeUnit: json['kode_unit']?.toString(),
      jenis: json['jenis']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

/// Satu item riwayat atau detail pengajuan servis armada.
class ServisArmada {
  const ServisArmada({
    required this.id,
    required this.armadaId,
    this.platNomor,
    this.kodeUnit,
    this.jenisArmada,
    required this.tanggalAjuan,
    required this.status,
    required this.keluhan,
    this.kategori,
    this.odometerSaatAjuan,
    this.jamOperasionalSaatAjuan,
    this.diajukanOleh,
    this.disetujuiOleh,
    this.alasanPenolakan,
    this.catatanWorkshop,
    this.tanggalSelesai,
    this.totalBiaya,
    this.spareparts = const [],
  });

  final String id;
  final String armadaId;
  final String? platNomor;
  final String? kodeUnit;
  final String? jenisArmada;
  final String tanggalAjuan;

  /// Status: 'diajukan', 'disetujui', 'ditolak', 'dikerjakan', 'selesai'.
  final String status;
  final String keluhan;
  final String? kategori;
  final double? odometerSaatAjuan;
  final double? jamOperasionalSaatAjuan;
  final String? diajukanOleh;
  final String? disetujuiOleh;
  final String? alasanPenolakan;
  final String? catatanWorkshop;
  final String? tanggalSelesai;
  final double? totalBiaya;
  final List<ServisSparepartItem> spareparts;

  bool get isMenungguApproval => status == 'diajukan';
  bool get isDisetujui => status == 'disetujui';
  bool get isDitolak => status == 'ditolak';
  bool get isDikerjakan => status == 'dikerjakan';
  bool get isSelesai => status == 'selesai';

  factory ServisArmada.fromJson(Map<String, dynamic> json) {
    final armada = json['armada'] is Map
        ? Map<String, dynamic>.from(json['armada'] as Map)
        : null;
    final parts = json['spareparts'];

    return ServisArmada(
      id: json['id']?.toString() ?? '',
      armadaId: json['armada_id']?.toString() ??
          armada?['id']?.toString() ??
          '',
      platNomor: json['plat_nomor']?.toString() ??
          armada?['plat_nomor']?.toString(),
      kodeUnit: json['kode_unit']?.toString() ??
          armada?['kode_unit']?.toString(),
      jenisArmada: json['jenis_armada']?.toString() ??
          armada?['jenis']?.toString(),
      tanggalAjuan: json['tanggal_ajuan']?.toString() ??
          json['created_at']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'diajukan',
      keluhan: json['keluhan']?.toString() ??
          json['deskripsi']?.toString() ??
          '',
      kategori: json['kategori']?.toString(),
      odometerSaatAjuan:
          (json['odometer_saat_ajuan'] as num?)?.toDouble() ??
              (json['odo_km'] as num?)?.toDouble(),
      jamOperasionalSaatAjuan:
          (json['jam_operasional_saat_ajuan'] as num?)?.toDouble() ??
              (json['jam_operasional'] as num?)?.toDouble(),
      diajukanOleh: json['diajukan_oleh'] is Map
          ? json['diajukan_oleh']['name']?.toString()
          : json['diajukan_oleh']?.toString(),
      disetujuiOleh: json['disetujui_oleh'] is Map
          ? json['disetujui_oleh']['name']?.toString()
          : json['disetujui_oleh']?.toString(),
      alasanPenolakan: json['alasan_penolakan']?.toString(),
      catatanWorkshop: json['catatan_workshop']?.toString(),
      tanggalSelesai: json['tanggal_selesai']?.toString(),
      totalBiaya: (json['total_biaya'] as num?)?.toDouble(),
      spareparts: [
        if (parts is List)
          for (final p in parts)
            if (p is Map)
              ServisSparepartItem.fromJson(Map<String, dynamic>.from(p)),
      ],
    );
  }
}

/// Item sparepart yang digunakan dalam pengerjaan servis.
class ServisSparepartItem {
  const ServisSparepartItem({
    required this.id,
    required this.namaBarang,
    required this.jumlah,
    this.satuan,
    this.hargaSatuan,
    this.totalHarga,
  });

  final String id;
  final String namaBarang;
  final double jumlah;
  final String? satuan;
  final double? hargaSatuan;
  final double? totalHarga;

  factory ServisSparepartItem.fromJson(Map<String, dynamic> json) {
    return ServisSparepartItem(
      id: json['id']?.toString() ?? '',
      namaBarang: json['nama_barang']?.toString() ??
          json['nama']?.toString() ??
          '',
      jumlah: (json['jumlah'] as num?)?.toDouble() ??
          (json['qty'] as num?)?.toDouble() ??
          1.0,
      satuan: json['satuan']?.toString(),
      hargaSatuan: (json['harga_satuan'] as num?)?.toDouble(),
      totalHarga: (json['total_harga'] as num?)?.toDouble(),
    );
  }
}

/// Halaman riwayat servis armada (paginasi).
class ServisArmadaPage {
  const ServisArmadaPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<ServisArmada> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static ServisArmadaPage fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'] ?? map['data'];
    return ServisArmadaPage(
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map)
              ServisArmada.fromJson(Map<String, dynamic>.from(e)),
      ],
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }
}
