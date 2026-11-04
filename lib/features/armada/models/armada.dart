/// Model modul Armada (driver) — docs/api-mobile.md §Armada.
///
/// Dibaca dari endpoint `armada/saya`, `armada/ritase`, dan
/// `armada/checklist-hari-ini`.
library;

import '../../../core/json_num.dart';

/// Kendaraan yang saat ini dipegang driver (ArmadaDriver aktif).
class ArmadaSaya {
  const ArmadaSaya({
    required this.id,
    required this.platNomor,
    this.kodeUnit,
    this.jenis,
    this.tipeUnit,
    this.modelTarif,
    this.tahun,
    this.kapasitas,
    this.status,
    this.unitBisnis,
    this.titikId,
    this.titikNama,
    this.proyekId,
    this.odoTerkini,
    this.jamOperasionalTerkini,
    this.helperAktifCount = 0,
    this.fotoUrl,
    this.dokumenBerkala = const [],
  });

  final String id;
  final String platNomor;
  final String? kodeUnit;
  final String? jenis;

  /// Tipe unit: 'kendaraan' atau 'alat_berat_stasioner'.
  /// Menentukan apakah unit pakai ODO (km) atau Jam Operasional (HM).
  final String? tipeUnit;

  final String? modelTarif;
  final int? tahun;
  final String? kapasitas;
  final String? status;
  final String? unitBisnis;
  final String? titikId;
  final String? titikNama;
  final String? proyekId;
  final double? odoTerkini;
  final double? jamOperasionalTerkini;

  /// Ringkasan dokumen berkala mendekati jatuh tempo (TD-C2).
  final List<DokumenBerkalaItem> dokumenBerkala;

  /// Jumlah helper yang aktif hari ini pada unit ini (endpoint armada/saya).
  final int helperAktifCount;

  /// URL foto/thumbnail unit dari server (TD-C1).
  final String? fotoUrl;

  /// True jika unit ini alat berat stasioner (pakai Jam Operasional, bukan ODO).
  bool get isAlatBerat => tipeUnit == 'alat_berat_stasioner';

  /// True jika unit ini kendaraan (pakai ODO/km).
  bool get isKendaraan => !isAlatBerat;

  factory ArmadaSaya.fromJson(Map<String, dynamic> json) {
    final titik = json['titik'] is Map
        ? Map<String, dynamic>.from(json['titik'] as Map)
        : null;
    return ArmadaSaya(
      id: json['id']?.toString() ?? '',
      platNomor: json['plat_nomor']?.toString() ?? '-',
      kodeUnit: json['kode_unit']?.toString(),
      jenis: json['jenis']?.toString(),
      tipeUnit: json['tipe_unit']?.toString(),
      modelTarif: json['model_tarif']?.toString(),
      tahun: parseInt(json['tahun']),
      kapasitas: json['kapasitas']?.toString(),
      status: json['status']?.toString(),
      unitBisnis: json['unit_bisnis']?.toString(),
      titikId: titik?['id']?.toString(),
      titikNama: titik?['nama']?.toString(),
      proyekId: (titik?['proyek_id'] ?? json['proyek_id'])?.toString(),
      odoTerkini: parseNum(json['odo_terkini']),
      jamOperasionalTerkini: parseNum(json['jam_operasional_terkini']),
      helperAktifCount: parseInt(json['helper_aktif_count']) ?? 0,
      fotoUrl: (json['foto_url'] ?? json['foto_unit_url'])?.toString(),
      dokumenBerkala: [
        if (json['dokumen_berkala'] is List)
          for (final d in json['dokumen_berkala'] as List)
            if (d is Map)
              DokumenBerkalaItem.fromJson(Map<String, dynamic>.from(d))
        else if (json['dokumen'] is List)
          for (final d in json['dokumen'] as List)
            if (d is Map)
              DokumenBerkalaItem.fromJson(Map<String, dynamic>.from(d)),
      ],
    );
  }
}

/// Item dokumen berkala (Pajak, STNK, KIR, dll) pada unit armada (TD-C2).
class DokumenBerkalaItem {
  const DokumenBerkalaItem({
    required this.jenis,
    this.nomor,
    this.jatuhTempo,
    this.sisaHari,
  });

  final String jenis;
  final String? nomor;
  final String? jatuhTempo;
  final int? sisaHari;

  /// True bila jatuh tempo dalam 30 hari ke depan atau sudah lewat.
  bool get isJatuhTempoSegera => sisaHari != null && sisaHari! <= 30;

  factory DokumenBerkalaItem.fromJson(Map<String, dynamic> json) {
    return DokumenBerkalaItem(
      jenis: json['jenis']?.toString() ??
          json['nama']?.toString() ??
          json['kategori']?.toString() ??
          'Dokumen',
      nomor: json['nomor']?.toString() ?? json['nomor_dokumen']?.toString(),
      jatuhTempo: json['jatuh_tempo']?.toString() ??
          json['tanggal_kadaluarsa']?.toString() ??
          json['tanggal_berlaku_sampai']?.toString(),
      sisaHari: parseInt(json['sisa_hari']) ??
          parseInt(json['hari_tersisa']) ??
          parseInt(json['days_left']),
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
    this.armadaId,
    this.armadaPlat,
    this.driverNama,
    this.ruteAsal,
    this.ruteTujuan,
    this.proyek,
    this.titik,
    this.wajibJembatanTimbang,
    this.statusVerifikasiLogistik,
    this.statusVerifikasiSecurity,
    this.jumlahDriver,
    this.jumlahVerifikasiLogistik,
    this.satuanMuatan,
    this.adaSelisih,
    this.taraMasterKg,
    this.beratKosongKg,
    this.beratIsiKg,
    this.beratNettoKg,
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
  final String? armadaId;
  final String? armadaPlat;
  final String? driverNama;
  final String? ruteAsal;
  final String? ruteTujuan;
  final String? proyek;
  final String? titik;

  // TD-E1..E5: Verifikasi muatan & timbang
  final bool? wajibJembatanTimbang;
  final String? statusVerifikasiLogistik;
  final String? statusVerifikasiSecurity;
  final double? jumlahDriver;
  final double? jumlahVerifikasiLogistik;
  final String? satuanMuatan;
  final bool? adaSelisih;
  final double? taraMasterKg;
  final double? beratKosongKg;
  final double? beratIsiKg;
  final double? beratNettoKg;

  bool get isVerifiedLogistik => statusVerifikasiLogistik == 'terverifikasi';
  bool get isVerifiedSecurity => statusVerifikasiSecurity == 'terverifikasi';
  bool get isMenungguVerifikasi =>
      (wajibJembatanTimbang == true && !isVerifiedLogistik) ||
      statusVerifikasiLogistik == 'menunggu';
  bool get hasSelisih =>
      adaSelisih == true ||
      (jumlahDriver != null &&
          jumlahVerifikasiLogistik != null &&
          (jumlahDriver! - jumlahVerifikasiLogistik!).abs() > 0.001);
  bool get hasVerifikasiData =>
      statusVerifikasiLogistik != null ||
      statusVerifikasiSecurity != null ||
      wajibJembatanTimbang == true ||
      jumlahDriver != null;

  factory RitaseItem.fromJson(Map<String, dynamic> json) {
    final rute = json['rute'] is Map
        ? Map<String, dynamic>.from(json['rute'] as Map)
        : null;
    final ruteAsal = rute?['asal']?.toString() ?? json['rute_asal']?.toString();
    final isWajibTimbang = json['wajib_jembatan_timbang'] == true ||
        (ruteAsal != null && ruteAsal.toLowerCase().contains('kantor pusat'));

    final muatanMap = json['muatan'] is Map ? json['muatan'] as Map : null;
    final verifLogistikMap = json['verifikasi_logistik'] is Map ? json['verifikasi_logistik'] as Map : null;
    final verifSecurityMap = json['verifikasi_security'] is Map ? json['verifikasi_security'] as Map : null;
    final timbangMap = json['timbang'] is Map ? json['timbang'] as Map : null;

    final jmlDriver = parseNum(json['jumlah_driver']) ??
        parseNum(muatanMap?['jumlah_driver']) ??
        parseNum(json['muatan_jumlah']) ??
        parseNum(json['jumlah_volume']);

    final jmlVerif = parseNum(json['jumlah_verifikasi']) ??
        parseNum(json['jumlah_verifikasi_logistik']) ??
        parseNum(verifLogistikMap?['jumlah_verifikasi']);

    return RitaseItem(
      id: json['id']?.toString() ?? '',
      tanggal: json['tanggal']?.toString(),
      kategori: json['kategori']?.toString(),
      material: json['material']?.toString() ??
          json['muatan_jenis']?.toString() ??
          muatanMap?['jenis_muatan']?.toString(),
      jumlahRit: parseInt(json['jumlah_rit']),
      tarifPerRit: parseNum(json['tarif_per_rit_snapshot']),
      totalUpahRit: parseNum(json['total_upah_rit']),
      status: json['status']?.toString(),
      catatan: json['catatan']?.toString(),
      customer: json['customer']?.toString(),
      armadaId: json['armada_id']?.toString() ?? json['armada']?['id']?.toString(),
      armadaPlat: json['armada_plat']?.toString() ?? json['armada']?['plat_nomor']?.toString(),
      driverNama: json['driver_nama']?.toString() ?? json['driver']?['nama']?.toString(),
      ruteAsal: ruteAsal,
      ruteTujuan: rute?['tujuan']?.toString() ?? json['rute_tujuan']?.toString(),
      proyek: json['proyek'] is Map ? (json['proyek'] as Map)['nama']?.toString() : json['proyek']?.toString(),
      titik: json['titik'] is Map ? (json['titik'] as Map)['nama']?.toString() : json['titik']?.toString(),
      wajibJembatanTimbang: isWajibTimbang,
      statusVerifikasiLogistik: json['status_verifikasi_logistik']?.toString() ??
          verifLogistikMap?['status']?.toString(),
      statusVerifikasiSecurity: json['status_verifikasi_security']?.toString() ??
          verifSecurityMap?['status']?.toString(),
      jumlahDriver: jmlDriver,
      jumlahVerifikasiLogistik: jmlVerif,
      satuanMuatan: json['satuan_muatan']?.toString() ??
          json['muatan_satuan']?.toString() ??
          muatanMap?['satuan']?.toString() ??
          json['satuan_volume']?.toString(),
      adaSelisih: json['ada_selisih'] == true || json['selisih'] == true,
      taraMasterKg: parseNum(json['tara_master_kg']) ??
          parseNum(json['armada']?['tara_master_kg']),
      beratKosongKg: parseNum(json['berat_kosong_kg']) ??
          parseNum(timbangMap?['berat_kosong_kg']),
      beratIsiKg: parseNum(json['berat_isi_kg']) ??
          parseNum(timbangMap?['berat_isi_kg']),
      beratNettoKg: parseNum(json['berat_netto_kg']) ??
          parseNum(timbangMap?['berat_netto_kg']),
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
      currentPage: parseInt(map['current_page']) ?? 1,
      lastPage: parseInt(map['last_page']) ?? 1,
      total: parseInt(map['total']) ?? 0,
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
    this.tipeUnit,
    this.tanggal,
    required this.sudahIsi,
    this.checklistId,
    this.status,
    this.kondisiBaik,
    this.itemBermasalah,
    this.solarLiter,
    this.odoKm,
    this.jamOperasional,
    this.awal,
    this.akhir,
    this.pengisian = const [],
    this.opsiStokSolar = const [],
    this.bagianDefault = const [],
  });

  final String armadaId;
  final String platNomor;
  final String? kodeUnit;
  final String? jenis;

  /// Tipe unit: 'kendaraan' atau 'alat_berat_stasioner'.
  final String? tipeUnit;

  final String? tanggal;
  final bool sudahIsi;
  final String? checklistId;

  /// 'selesai' bila checklist akhir sudah ada, 'berjalan' bila belum.
  final String? status;
  final bool? kondisiBaik;
  final String? itemBermasalah;

  /// Section 21: solar yang diisi (liter). Diisi dari `awal.hm_odo`/pengisian
  /// pada kontrak lama; pada kontrak baru selalu null (lihat [pengisian]).
  final double? solarLiter;

  /// Section 21: ODO-meter saat ini (km) — dari `awal.odo_pagi`.
  final double? odoKm;

  /// Section 21: jam operasional (untuk alat stasioner) — dari `awal.hm_odo`.
  final double? jamOperasional;

  /// Checklist awal hari ini (null bila belum diisi).
  final ArmadaChecklistAwal? awal;

  /// Checklist akhir hari ini (null bila belum diisi).
  final ArmadaChecklistAkhirData? akhir;

  /// Daftar pengisian solar hari ini.
  final List<PengisianSolarItem> pengisian;

  /// Opsi dropdown stok solar.
  final List<OpsiStokSolar> opsiStokSolar;

  /// Daftar bagian default checklist.
  final List<String> bagianDefault;

  /// True bila unit ini alat berat stasioner (pakai Jam Operasional/HM).
  bool get isAlatBerat => tipeUnit == 'alat_berat_stasioner';

  /// Total liter pengisian solar hari ini.
  double get totalLiterPengisian =>
      pengisian.fold<double>(0, (s, p) => s + (p.liter ?? 0));

  ArmadaChecklist copyWith({
    ArmadaChecklistAwal? awal,
    ArmadaChecklistAkhirData? akhir,
    List<PengisianSolarItem>? pengisian,
    String? status,
    bool? sudahIsi,
  }) => ArmadaChecklist(
    armadaId: armadaId,
    platNomor: platNomor,
    kodeUnit: kodeUnit,
    jenis: jenis,
    tipeUnit: tipeUnit,
    tanggal: tanggal,
    sudahIsi: sudahIsi ?? this.sudahIsi,
    checklistId: checklistId,
    status: status ?? this.status,
    kondisiBaik: kondisiBaik,
    itemBermasalah: itemBermasalah,
    solarLiter: solarLiter,
    odoKm: odoKm,
    jamOperasional: jamOperasional,
    awal: awal ?? this.awal,
    akhir: akhir ?? this.akhir,
    pengisian: pengisian ?? this.pengisian,
    opsiStokSolar: opsiStokSolar,
    bagianDefault: bagianDefault,
  );

  factory ArmadaChecklist.fromJson(Map<String, dynamic> json) {
    final awal = json['awal'] is Map
        ? ArmadaChecklistAwal.fromJson(
            Map<String, dynamic>.from(json['awal'] as Map),
          )
        : null;
    final akhir = json['akhir'] is Map
        ? ArmadaChecklistAkhirData.fromJson(
            Map<String, dynamic>.from(json['akhir'] as Map),
          )
        : null;
    final pengisianRaw = json['pengisian_solar'];
    final opsiRaw = json['opsi_stok_solar'];
    final bagianRaw = json['bagian_default'];
    return ArmadaChecklist(
      armadaId: json['armada_id']?.toString() ?? '',
      platNomor: json['plat_nomor']?.toString() ?? '-',
      kodeUnit: json['kode_unit']?.toString(),
      jenis: json['jenis']?.toString(),
      tipeUnit: json['tipe_unit']?.toString(),
      tanggal: json['tanggal']?.toString(),
      sudahIsi: json['sudah_isi'] == true,
      checklistId: json['checklist_id']?.toString(),
      status: json['status']?.toString(),
      kondisiBaik:
          (json['kondisi_baik'] as bool?) ?? awal?.kondisiBaik,
      itemBermasalah:
          json['item_bermasalah']?.toString() ?? awal?.itemBermasalah,
      solarLiter: parseNum(json['solar_liter']),
      odoKm:
          parseNum(json['odo_km']) ??
          parseNum(json['odo_sore']) ??
          parseNum(json['odo_pagi']) ??
          awal?.odoPagi,
      jamOperasional:
          parseNum(json['jam_operasional']) ??
          parseNum(json['hm_odo']) ??
          awal?.hmOdo,
      awal: awal,
      akhir: akhir,
      pengisian: [
        if (pengisianRaw is List)
          for (final e in pengisianRaw)
            if (e is Map)
              PengisianSolarItem.fromJson(Map<String, dynamic>.from(e)),
      ],
      opsiStokSolar: [
        if (opsiRaw is List)
          for (final e in opsiRaw)
            if (e is Map)
              OpsiStokSolar.fromJson(Map<String, dynamic>.from(e)),
      ],
      bagianDefault: [
        if (bagianRaw is List) for (final e in bagianRaw) e.toString(),
      ],
    );
  }
}

/// Opsi stok solar (dropdown 6 level).
class OpsiStokSolar {
  const OpsiStokSolar({required this.value, required this.label});

  final String value;
  final String label;

  factory OpsiStokSolar.fromJson(Map<String, dynamic> json) => OpsiStokSolar(
    value: json['value']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
  );
}

/// Checklist awal hari ini untuk satu armada.
class ArmadaChecklistAwal {
  const ArmadaChecklistAwal({
    required this.checklistId,
    this.kondisiBaik,
    this.itemBermasalah,
    this.items = const [],
    this.stokSolar,
    this.stokSolarLabel,
    this.fotoStokSolarUrl,
    this.odoPagi,
    this.fotoOdoPagiUrl,
    this.jamMulaiOperasi,
    this.hmOdo,
    this.bisaDiedit = true,
    this.alasanTerkunci,
  });

  final String checklistId;
  final bool? kondisiBaik;
  final String? itemBermasalah;
  final List<Map<String, dynamic>> items;
  final String? stokSolar;
  final String? stokSolarLabel;
  final String? fotoStokSolarUrl;
  final double? odoPagi;
  final String? fotoOdoPagiUrl;
  final String? jamMulaiOperasi;
  final double? hmOdo;
  final bool bisaDiedit;
  final String? alasanTerkunci;

  factory ArmadaChecklistAwal.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    return ArmadaChecklistAwal(
      checklistId: json['checklist_id']?.toString() ?? '',
      kondisiBaik: json['kondisi_baik'] as bool?,
      itemBermasalah: json['item_bermasalah']?.toString(),
      items: [
        if (itemsRaw is List)
          for (final e in itemsRaw)
            if (e is Map) Map<String, dynamic>.from(e),
      ],
      stokSolar: json['stok_solar']?.toString(),
      stokSolarLabel: json['stok_solar_label']?.toString(),
      fotoStokSolarUrl: json['foto_stok_solar_url']?.toString(),
      odoPagi: parseNum(json['odo_pagi']),
      fotoOdoPagiUrl: json['foto_odo_pagi_url']?.toString(),
      jamMulaiOperasi: json['jam_mulai_operasi']?.toString(),
      hmOdo: parseNum(json['hm_odo']),
      bisaDiedit: json['bisa_diedit'] != false,
      alasanTerkunci: json['alasan_terkunci']?.toString(),
    );
  }
}

/// Checklist akhir hari ini untuk satu armada.
class ArmadaChecklistAkhirData {
  const ArmadaChecklistAkhirData({
    required this.checklistAkhirId,
    this.kondisiBaik,
    this.itemBermasalah,
    this.items = const [],
    this.stokSolar,
    this.stokSolarLabel,
    this.fotoStokSolarUrl,
    this.odoAkhir,
    this.fotoOdoAkhirUrl,
    this.jamSelesaiOperasi,
    this.hmAkhir,
    this.odoAnomali = false,
  });

  final String checklistAkhirId;
  final bool? kondisiBaik;
  final String? itemBermasalah;
  final List<Map<String, dynamic>> items;
  final String? stokSolar;
  final String? stokSolarLabel;
  final String? fotoStokSolarUrl;
  final double? odoAkhir;
  final String? fotoOdoAkhirUrl;
  final String? jamSelesaiOperasi;
  final double? hmAkhir;
  final bool odoAnomali;

  factory ArmadaChecklistAkhirData.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    return ArmadaChecklistAkhirData(
      checklistAkhirId: json['checklist_akhir_id']?.toString() ?? '',
      kondisiBaik: json['kondisi_baik'] as bool?,
      itemBermasalah: json['item_bermasalah']?.toString(),
      items: [
        if (itemsRaw is List)
          for (final e in itemsRaw)
            if (e is Map) Map<String, dynamic>.from(e),
      ],
      stokSolar: json['stok_solar']?.toString(),
      stokSolarLabel: json['stok_solar_label']?.toString(),
      fotoStokSolarUrl: json['foto_stok_solar_url']?.toString(),
      odoAkhir: parseNum(json['odo_akhir']),
      fotoOdoAkhirUrl: json['foto_odo_akhir_url']?.toString(),
      jamSelesaiOperasi: json['jam_selesai_operasi']?.toString(),
      hmAkhir: parseNum(json['hm_akhir']),
      odoAnomali: json['odo_anomali'] == true,
    );
  }
}

/// Satu catatan pengisian solar.
class PengisianSolarItem {
  const PengisianSolarItem({
    required this.id,
    this.waktu,
    this.tanggal,
    this.odoAtauHm,
    this.liter,
    this.nominalRp,
    this.hargaPerLiter,
    this.fotoOdoUrl,
    this.fotoNotaUrl,
    this.catatan,
    this.driver,
    this.notaLengkap,
  });

  final String id;
  final String? waktu;
  final String? tanggal;
  final double? odoAtauHm;
  final double? liter;
  final double? nominalRp;
  final double? hargaPerLiter;
  final String? fotoOdoUrl;
  final String? fotoNotaUrl;
  final String? catatan;
  final String? driver;

  /// True jika foto nota tersedia (TD-A2).
  final bool? notaLengkap;

  factory PengisianSolarItem.fromJson(Map<String, dynamic> json) =>
      PengisianSolarItem(
        id: json['id']?.toString() ?? '',
        waktu: json['waktu']?.toString(),
        tanggal: json['tanggal']?.toString(),
        odoAtauHm: parseNum(json['odo_atau_hm']),
        liter: parseNum(json['liter']),
        nominalRp: parseNum(json['nominal_rp']),
        hargaPerLiter: parseNum(json['harga_per_liter']),
        fotoOdoUrl: json['foto_odo_url']?.toString(),
        fotoNotaUrl: json['foto_nota_url']?.toString(),
        catatan: json['catatan']?.toString(),
        driver: json['driver']?.toString(),
        notaLengkap: json['nota_lengkap'] as bool? ??
            (json['foto_nota_url'] != null || json['foto_nota'] != null),
      );
}

/// Satu baris ODO awal proyek (1 per armada x proyek).
class OdoAwalProyekItem {
  const OdoAwalProyekItem({
    required this.id,
    required this.armadaId,
    this.armadaPlat,
    this.proyekId,
    this.proyekNama,
    this.odoAwal,
    this.jarakKePusatKm,
    this.tanggal,
  });

  final String id;
  final String armadaId;
  final String? armadaPlat;
  final String? proyekId;
  final String? proyekNama;
  final double? odoAwal;
  final double? jarakKePusatKm;
  final String? tanggal;

  factory OdoAwalProyekItem.fromJson(Map<String, dynamic> json) =>
      OdoAwalProyekItem(
        id: json['id']?.toString() ?? '',
        armadaId: json['armada_id']?.toString() ?? '',
        armadaPlat: json['armada_plat']?.toString(),
        proyekId: json['proyek_id']?.toString(),
        proyekNama: json['proyek_nama']?.toString(),
        odoAwal: parseNum(json['odo_awal']),
        jarakKePusatKm: parseNum(json['jarak_ke_pusat_km']),
        tanggal: json['tanggal']?.toString(),
      );
}
