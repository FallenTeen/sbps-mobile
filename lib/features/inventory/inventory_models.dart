class InventorySummary {
  const InventorySummary({
    required this.totalItem,
    required this.nilaiStok,
    required this.stokRendahCount,
    required this.requestPendingCount,
  });

  final int totalItem;
  final double nilaiStok;
  final int stokRendahCount;
  final int requestPendingCount;

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    return InventorySummary(
      totalItem: (json['total_item'] as num?)?.toInt() ?? 0,
      nilaiStok: (json['nilai_stok'] as num?)?.toDouble() ?? 0,
      stokRendahCount: (json['stok_rendah_count'] as num?)?.toInt() ?? 0,
      requestPendingCount:
          (json['request_pending_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.stokSaatIni,
    required this.stokMinimum,
    required this.satuan,
    this.lokasiGudang,
  });

  final String id;
  final String nama;
  final String kategori;
  final int stokSaatIni;
  final int stokMinimum;
  final String satuan;
  final String? lokasiGudang;

  bool get isStokRendah => stokSaatIni < stokMinimum;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      nama: json['nama'] as String,
      kategori: json['kategori'] as String,
      stokSaatIni: (json['stok_saat_ini'] as num).toInt(),
      stokMinimum: (json['stok_minimum'] as num).toInt(),
      satuan: json['satuan'] as String,
      lokasiGudang: json['lokasi_gudang'] as String?,
    );
  }
}

class InventoryRequest {
  const InventoryRequest({
    required this.id,
    required this.workshopJobId,
    required this.platNomor,
    required this.kategoriServis,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String workshopJobId;
  final String platNomor;
  final String kategoriServis;
  final InventoryRequestStatus status;
  final List<InventoryRequestItem> items;
  final DateTime createdAt;

  int get totalItems => items.length;

  factory InventoryRequest.fromJson(Map<String, dynamic> json) {
    return InventoryRequest(
      id: json['id'] as String,
      workshopJobId: json['workshop_job_id'] as String,
      platNomor: json['plat_nomor'] as String,
      kategoriServis: json['kategori_servis'] as String,
      status: InventoryRequestStatus.fromString(json['status'] as String),
      items: (json['items'] as List<dynamic>)
          .map((e) => InventoryRequestItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

enum InventoryRequestStatus {
  pending,
  diproses,
  selesai,
  ditolak;

  factory InventoryRequestStatus.fromString(String value) {
    return switch (value) {
      'pending' => InventoryRequestStatus.pending,
      'diproses' => InventoryRequestStatus.diproses,
      'selesai' => InventoryRequestStatus.selesai,
      'ditolak' => InventoryRequestStatus.ditolak,
      _ => InventoryRequestStatus.pending,
    };
  }

  String get label {
    return switch (this) {
      InventoryRequestStatus.pending => 'Pending',
      InventoryRequestStatus.diproses => 'Diproses',
      InventoryRequestStatus.selesai => 'Selesai',
      InventoryRequestStatus.ditolak => 'Ditolak',
    };
  }
}

class InventoryRequestItem {
  const InventoryRequestItem({
    required this.id,
    required this.namaBarang,
    required this.jumlahDiminta,
    this.jumlahTersedia,
    required this.satuan,
    required this.status,
  });

  final String id;
  final String namaBarang;
  final int jumlahDiminta;
  final int? jumlahTersedia;
  final String satuan;
  final InventoryRequestItemStatus status;

  factory InventoryRequestItem.fromJson(Map<String, dynamic> json) {
    return InventoryRequestItem(
      id: json['id'] as String,
      namaBarang: json['nama_barang'] as String,
      jumlahDiminta: (json['jumlah_diminta'] as num).toInt(),
      jumlahTersedia: (json['jumlah_tersedia'] as num?)?.toInt(),
      satuan: json['satuan'] as String,
      status: InventoryRequestItemStatus.fromString(json['status'] as String),
    );
  }
}

enum InventoryRequestItemStatus {
  tersedia,
  kurang,
  tidakTersedia;

  factory InventoryRequestItemStatus.fromString(String value) {
    return switch (value) {
      'tersedia' => InventoryRequestItemStatus.tersedia,
      'kurang' => InventoryRequestItemStatus.kurang,
      'tidak_tersedia' => InventoryRequestItemStatus.tidakTersedia,
      _ => InventoryRequestItemStatus.tidakTersedia,
    };
  }

  String get label {
    return switch (this) {
      InventoryRequestItemStatus.tersedia => 'Tersedia',
      InventoryRequestItemStatus.kurang => 'Kurang',
      InventoryRequestItemStatus.tidakTersedia => 'Tidak Tersedia',
    };
  }
}

class OpnameItem {
  const OpnameItem({
    required this.id,
    required this.namaBarang,
    required this.kategori,
    required this.jumlahSistem,
    this.jumlahFisik,
    required this.satuan,
  });

  final String id;
  final String namaBarang;
  final String kategori;
  final int jumlahSistem;
  final int? jumlahFisik;
  final String satuan;

  bool get hasSelisih => jumlahFisik != null && jumlahFisik != jumlahSistem;

  int? get selisih => jumlahFisik != null ? jumlahFisik! - jumlahSistem : null;

  factory OpnameItem.fromJson(Map<String, dynamic> json) {
    return OpnameItem(
      id: json['id'] as String,
      namaBarang: json['nama_barang'] as String,
      kategori: json['kategori'] as String,
      jumlahSistem: (json['jumlah_sistem'] as num).toInt(),
      jumlahFisik: (json['jumlah_fisik'] as num?)?.toInt(),
      satuan: json['satuan'] as String,
    );
  }
}

/// Satu baris hasil hitung fisik untuk dikirim ke POST /inventory/opname.
class OpnameSubmitItem {
  const OpnameSubmitItem({
    required this.bahanBakuId,
    required this.saldoFisik,
    this.catatan,
  });

  final String bahanBakuId;
  final int saldoFisik;
  final String? catatan;

  Map<String, dynamic> toJson() => {
    'bahan_baku_id': bahanBakuId,
    'saldo_fisik': saldoFisik,
    if (catatan != null && catatan!.trim().isNotEmpty) 'catatan': catatan,
  };
}

// ---------------------------------------------------------------------------
// Riwayat mutasi stok (GET /inventory/mutasi & /inventory/materials/{id}/mutasi)
// ---------------------------------------------------------------------------

enum MutasiTipe {
  masuk,
  keluar;

  factory MutasiTipe.fromString(String value) {
    return value == 'masuk' ? MutasiTipe.masuk : MutasiTipe.keluar;
  }

  String get label =>
      this == MutasiTipe.masuk ? 'Masuk' : 'Keluar';
}

/// Asal catatan mutasi — dipetakan dari `referensi_type` di backend
/// (PurchaseOrder / ProductionSession / StokOpname / pengajuan servis / manual).
enum MutasiSumber {
  pembelian,
  produksi,
  opname,
  requestSparepart,
  manual;

  factory MutasiSumber.fromString(String value) {
    return switch (value) {
      'pembelian' => MutasiSumber.pembelian,
      'produksi' => MutasiSumber.produksi,
      'opname' => MutasiSumber.opname,
      'request_sparepart' => MutasiSumber.requestSparepart,
      _ => MutasiSumber.manual,
    };
  }

  String get label {
    return switch (this) {
      MutasiSumber.pembelian => 'Pembelian',
      MutasiSumber.produksi => 'Produksi',
      MutasiSumber.opname => 'Stok Opname',
      MutasiSumber.requestSparepart => 'Request Sparepart',
      MutasiSumber.manual => 'Manual',
    };
  }
}

/// Satu baris riwayat mutasi stok.
class StokMutasi {
  const StokMutasi({
    required this.id,
    required this.bahanBakuId,
    required this.namaBarang,
    required this.kategori,
    required this.satuan,
    required this.tipe,
    required this.jumlah,
    required this.sumber,
    this.referensiId,
    this.catatan,
    required this.createdAt,
    required this.createdBy,
  });

  final String id;
  final String bahanBakuId;
  final String namaBarang;
  final String kategori;
  final String satuan;
  final MutasiTipe tipe;
  final double jumlah;
  final MutasiSumber sumber;
  final String? referensiId;
  final String? catatan;
  final DateTime createdAt;
  final String createdBy;

  factory StokMutasi.fromJson(Map<String, dynamic> json) {
    return StokMutasi(
      id: json['id'] as String? ?? '',
      bahanBakuId: json['bahan_baku_id'] as String? ?? '',
      namaBarang: json['nama_barang'] as String? ?? '-',
      kategori: json['kategori'] as String? ?? '-',
      satuan: json['satuan'] as String? ?? '-',
      tipe: MutasiTipe.fromString(json['tipe'] as String? ?? 'keluar'),
      jumlah: (json['jumlah'] as num?)?.toDouble() ?? 0,
      sumber: MutasiSumber.fromString(json['sumber'] as String? ?? ''),
      referensiId: json['referensi_id'] as String?,
      catatan: json['catatan'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      createdBy: json['created_by'] as String? ?? 'Sistem',
    );
  }
}

/// Halaman riwayat mutasi (`{ items, pagination }`) — format sama dengan
/// riwayat QC / ritase.
class StokMutasiPage {
  const StokMutasiPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<StokMutasi> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static StokMutasiPage fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    final pag = map['pagination'];
    final pagMap = pag is Map ? Map<String, dynamic>.from(pag) : const {};
    return StokMutasiPage(
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map) StokMutasi.fromJson(Map<String, dynamic>.from(e)),
      ],
      currentPage: (pagMap['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagMap['last_page'] as num?)?.toInt() ?? 1,
      total: (pagMap['total'] as num?)?.toInt() ?? 0,
    );
  }
}
