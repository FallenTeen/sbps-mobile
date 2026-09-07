/// Model modul Armada (driver) — docs/api-mobile.md §Armada.
///
/// Dibaca dari endpoint `armada/saya`, `armada/ritase`, dan
/// `armada/checklist-hari-ini`.
library;

/// Kendaraan yang saat ini dipegang driver (ArmadaDriver aktif).
class ArmadaSaya {
  const ArmadaSaya({
    required this.id,
    required this.platNomor,
    this.kodeUnit,
    this.jenis,
    this.modelTarif,
    this.tahun,
    this.kapasitas,
    this.status,
    this.unitBisnis,
    this.titikId,
    this.titikNama,
  });

  final String id;
  final String platNomor;
  final String? kodeUnit;
  final String? jenis;
  final String? modelTarif;
  final int? tahun;
  final String? kapasitas;
  final String? status;
  final String? unitBisnis;
  final String? titikId;
  final String? titikNama;

  factory ArmadaSaya.fromJson(Map<String, dynamic> json) {
    final titik = json['titik'] is Map
        ? Map<String, dynamic>.from(json['titik'] as Map)
        : null;
    return ArmadaSaya(
      id: json['id']?.toString() ?? '',
      platNomor: json['plat_nomor']?.toString() ?? '',
      kodeUnit: json['kode_unit']?.toString(),
      jenis: json['jenis']?.toString(),
      modelTarif: json['model_tarif']?.toString(),
      tahun: (json['tahun'] as num?)?.toInt(),
      kapasitas: json['kapasitas']?.toString(),
      status: json['status']?.toString(),
      unitBisnis: json['unit_bisnis']?.toString(),
      titikId: titik?['id']?.toString(),
      titikNama: titik?['nama']?.toString(),
    );
  }
}

/// Satu ritase/pengiriman milik driver.
class RitaseItem {
  const RitaseItem({
    required this.id,
    required this.tanggal,
    this.kategori,
    this.material,
    this.jumlahRit,
    this.tarifPerRit,
    this.totalUpahRit,
    this.status,
    this.catatan,
    this.customer,
    this.armadaPlat,
    this.ruteAsal,
    this.ruteTujuan,
    this.proyek,
    this.titik,
  });

  final String id;
  final String? tanggal;
  final String? kategori;
  final String? material;
  final int? jumlahRit;
  final double? tarifPerRit;
  final double? totalUpahRit;
  final String? status;
  final String? catatan;
  final String? customer;
  final String? armadaPlat;
  final String? ruteAsal;
  final String? ruteTujuan;
  final String? proyek;
  final String? titik;

  factory RitaseItem.fromJson(Map<String, dynamic> json) {
    final rute = json['rute'] is Map
        ? Map<String, dynamic>.from(json['rute'] as Map)
        : null;
    return RitaseItem(
      id: json['id']?.toString() ?? '',
      tanggal: json['tanggal']?.toString(),
      kategori: json['kategori']?.toString(),
      material: json['material']?.toString(),
      jumlahRit: (json['jumlah_rit'] as num?)?.toInt(),
      tarifPerRit: (json['tarif_per_rit_snapshot'] as num?)?.toDouble(),
      totalUpahRit: (json['total_upah_rit'] as num?)?.toDouble(),
      status: json['status']?.toString(),
      catatan: json['catatan']?.toString(),
      customer: json['customer']?.toString(),
      armadaPlat: json['armada_plat']?.toString(),
      ruteAsal: rute?['asal']?.toString(),
      ruteTujuan: rute?['tujuan']?.toString(),
      proyek: json['proyek']?.toString(),
      titik: json['titik']?.toString(),
    );
  }
}

/// Halaman riwayat ritase (`{ items, current_page, last_page, total }`).
class RitasePage {
  const RitasePage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<RitaseItem> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static RitasePage fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return RitasePage(
      items: [
        if (list is List)
          for (final e in list)
            RitaseItem.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      currentPage: (map['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (map['last_page'] as num?)?.toInt() ?? 1,
      total: (map['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Checklist harian satu armada untuk hari ini.
class ArmadaChecklist {
  const ArmadaChecklist({
    required this.armadaId,
    required this.platNomor,
    this.kodeUnit,
    this.jenis,
    this.tanggal,
    required this.sudahIsi,
    this.checklistId,
    this.kondisiBaik,
    this.itemBermasalah,
    this.solarLiter,
    this.odoKm,
    this.jamOperasional,
  });

  final String armadaId;
  final String platNomor;
  final String? kodeUnit;
  final String? jenis;
  final String? tanggal;
  final bool sudahIsi;
  final String? checklistId;
  final bool? kondisiBaik;
  final String? itemBermasalah;

  /// Section 21: solar yang diisi (liter).
  final double? solarLiter;

  /// Section 21: ODO-meter saat ini (km).
  final double? odoKm;

  /// Section 21: jam operasional (untuk alat stasioner).
  final double? jamOperasional;

  factory ArmadaChecklist.fromJson(Map<String, dynamic> json) {
    return ArmadaChecklist(
      armadaId: json['armada_id']?.toString() ?? '',
      platNomor: json['plat_nomor']?.toString() ?? '',
      kodeUnit: json['kode_unit']?.toString(),
      jenis: json['jenis']?.toString(),
      tanggal: json['tanggal']?.toString(),
      sudahIsi: json['sudah_isi'] == true,
      checklistId: json['checklist_id']?.toString(),
      kondisiBaik: json['kondisi_baik'] as bool?,
      itemBermasalah: json['item_bermasalah']?.toString(),
      solarLiter: (json['solar_liter'] as num?)?.toDouble(),
      odoKm: (json['odo_km'] as num?)?.toDouble(),
      jamOperasional: (json['jam_operasional'] as num?)?.toDouble(),
    );
  }
}
