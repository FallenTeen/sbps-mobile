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
