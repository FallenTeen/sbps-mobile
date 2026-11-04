/// Model Servis Armada — alur 4 bagian pengajuan, persetujuan, workshop, sparepart.
/// (docs manual-book Section 21 & api-mobile)
library;

import '../../../core/json_num.dart';

/// Model Master Armada untuk dropdown pilihan unit saat pengajuan servis dan overview armada.
class MasterArmada {
  const MasterArmada({
    required this.id,
    required this.platNomor,
    this.kodeUnit,
    this.jenis,
    this.status,
    this.tipeUnit,
    this.titikId,
    this.titikNama,
    this.odoTerkini,
    this.jamOperasionalTerkini,
  });

  final String id;
  final String platNomor;
  final String? kodeUnit;
  final String? jenis;
  final String? status;
  final String? tipeUnit;
  final String? titikId;
  final String? titikNama;
  final double? odoTerkini;
  final double? jamOperasionalTerkini;

  bool get isAlatBerat => tipeUnit == 'alat_berat_stasioner';
  bool get isKendaraan => !isAlatBerat;

  factory MasterArmada.fromJson(Map<String, dynamic> json) {
    final titik = json['titik'] is Map
        ? Map<String, dynamic>.from(json['titik'] as Map)
        : null;
    return MasterArmada(
      id: json['id']?.toString() ?? '',
      platNomor: json['plat_nomor']?.toString() ?? '-',
      kodeUnit: json['kode_unit']?.toString(),
      jenis: json['jenis']?.toString(),
      status: json['status']?.toString(),
      tipeUnit: json['tipe_unit']?.toString(),
      titikId: titik?['id']?.toString() ?? json['titik_id']?.toString(),
      titikNama: titik?['nama']?.toString() ?? json['titik_nama']?.toString(),
      odoTerkini: parseNum(json['odo_terkini']),
      jamOperasionalTerkini: parseNum(json['jam_operasional_terkini']),
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
    this.tipeServis = 'internal',
    this.namaBengkel,
    this.alamatBengkel,
    this.latitude,
    this.longitude,
    this.fotoBengkelUrl,
    this.rincianPekerjaan,
    this.totalBiayaEstimasi,
    this.totalBiayaResmi,
    this.verifikasiWorkshop,
    this.verifikasiWorkshopCatatan,
    this.verifikasiWorkshopOleh,
    this.verifikasiWorkshopPada,
    this.fotoNotaUrls = const [],
    this.fotoHasilUrls = const [],
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

  /// Tipe servis: 'internal' atau 'eksternal' (TD-B1). Default 'internal'.
  final String tipeServis;

  // ── Servis Eksternal Detail (TD-B2..B7) ───────────────────────────────────
  final String? namaBengkel;
  final String? alamatBengkel;
  final double? latitude;
  final double? longitude;
  final String? fotoBengkelUrl;
  final String? rincianPekerjaan;
  final double? totalBiayaEstimasi;
  final double? totalBiayaResmi;

  /// Verifikasi Workshop: 'belum', 'terverifikasi', 'bermasalah'
  final String? verifikasiWorkshop;
  final String? verifikasiWorkshopCatatan;
  final String? verifikasiWorkshopOleh;
  final String? verifikasiWorkshopPada;

  /// Foto nota bengkel (TD-B3, B4)
  final List<String> fotoNotaUrls;

  /// Foto hasil pengerjaan (TD-B4, B5)
  final List<String> fotoHasilUrls;

  bool get isEksternal => tipeServis.toLowerCase() == 'eksternal';
  bool get isInternal => !isEksternal;
  bool get hasNota => fotoNotaUrls.isNotEmpty;

  bool get isMenungguApproval => status == 'diajukan';
  bool get isDisetujui => status == 'disetujui';
  bool get isDitolak => status == 'ditolak';
  bool get isDikerjakan => status == 'dikerjakan';
  bool get isSelesai => status == 'selesai';

  factory ServisArmada.fromJson(Map<String, dynamic> json) {
    List<String> extractUrls(Object? value) {
      if (value is String) return value.isEmpty ? const [] : [value];
      if (value is List) {
        return [for (final item in value) ...extractUrls(item)];
      }
      if (value is Map) {
        return extractUrls(value['url'] ?? value['foto'] ?? value['foto_url']);
      }
      return const [];
    }

    final armada = json['armada'] is Map
        ? Map<String, dynamic>.from(json['armada'] as Map)
        : null;
    final parts = json['spareparts'];
    final eksternalDetail = json['eksternal_detail'] is Map
        ? Map<String, dynamic>.from(json['eksternal_detail'] as Map)
        : (json['servis_eksternal_detail'] is Map
              ? Map<String, dynamic>.from(
                  json['servis_eksternal_detail'] as Map,
                )
              : null);
    final notas =
        json['notas'] ??
        json['eksternal_notas'] ??
        json['foto_notas'] ??
        json['servis_eksternal_notas'];
    final hasilFotos =
        json['foto_hasil_kerja'] ??
        json['foto_hasil'] ??
        json['foto_hasil_urls'];

    return ServisArmada(
      id: json['id']?.toString() ?? '',
      armadaId:
          json['armada_id']?.toString() ?? armada?['id']?.toString() ?? '',
      platNomor:
          json['plat_nomor']?.toString() ?? armada?['plat_nomor']?.toString(),
      kodeUnit:
          json['kode_unit']?.toString() ?? armada?['kode_unit']?.toString(),
      jenisArmada:
          json['jenis_armada']?.toString() ?? armada?['jenis']?.toString(),
      tanggalAjuan:
          json['tanggal_ajuan']?.toString() ??
          json['created_at']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'diajukan',
      keluhan:
          json['keluhan']?.toString() ?? json['deskripsi']?.toString() ?? '',
      kategori: json['kategori']?.toString(),
      odometerSaatAjuan:
          parseNum(json['odometer_saat_ajuan']) ?? parseNum(json['odo_km']),
      jamOperasionalSaatAjuan:
          parseNum(json['jam_operasional_saat_ajuan']) ??
          parseNum(json['jam_operasional']),
      diajukanOleh: json['diajukan_oleh'] is Map
          ? json['diajukan_oleh']['name']?.toString()
          : json['kode_pengajuan']?.toString(),
      disetujuiOleh: json['disetujui_oleh'] is Map
          ? json['disetujui_oleh']['name']?.toString()
          : json['disetujui_oleh']?.toString(),
      alasanPenolakan: json['alasan_penolakan']?.toString(),
      catatanWorkshop: json['catatan_acc']?.toString(),
      tanggalSelesai: json['tanggal_selesai']?.toString(),
      totalBiaya: parseNum(json['total_biaya']),
      spareparts: [
        if (parts is List)
          for (final p in parts)
            if (p is Map)
              ServisSparepartItem.fromJson(Map<String, dynamic>.from(p)),
      ],
      tipeServis: json['tipe_servis']?.toString() ?? 'internal',
      namaBengkel: (eksternalDetail?['nama_bengkel'] ?? json['nama_bengkel'])
          ?.toString(),
      alamatBengkel:
          (eksternalDetail?['alamat_bengkel'] ?? json['alamat_bengkel'])
              ?.toString(),
      latitude: parseNum(eksternalDetail?['latitude'] ?? json['latitude']),
      longitude: parseNum(eksternalDetail?['longitude'] ?? json['longitude']),
      fotoBengkelUrl:
          extractUrls(
            eksternalDetail?['foto_bengkel_url'] ?? json['foto_bengkel_url'],
          ).firstOrNull ??
          (eksternalDetail?['foto_bengkel'] ?? json['foto_bengkel'])
              ?.toString(),
      rincianPekerjaan:
          (eksternalDetail?['rincian_pekerjaan'] ?? json['rincian_pekerjaan'])
              ?.toString(),
      totalBiayaEstimasi: parseNum(
        eksternalDetail?['total_biaya_estimasi'] ??
            json['total_biaya_estimasi'],
      ),
      totalBiayaResmi: parseNum(
        eksternalDetail?['total_biaya_resmi'] ?? json['total_biaya'],
      ),
      verifikasiWorkshop:
          (eksternalDetail?['verifikasi_workshop'] ??
                  json['verifikasi_workshop'])
              ?.toString(),
      verifikasiWorkshopCatatan:
          (eksternalDetail?['verifikasi_workshop_catatan'] ??
                  json['verifikasi_workshop_catatan'])
              ?.toString(),
      verifikasiWorkshopOleh:
          (eksternalDetail?['verifikasi_workshop_oleh'] ??
                  json['verifikasi_workshop_oleh'])
              ?.toString(),
      verifikasiWorkshopPada:
          (eksternalDetail?['verifikasi_workshop_pada'] ??
                  json['verifikasi_workshop_pada'])
              ?.toString(),
      fotoNotaUrls: [
        if (notas is List)
          for (final n in notas)
            if (n is Map && extractUrls(n['foto_nota_url']).isNotEmpty)
              ...extractUrls(n['foto_nota_url'])
            else if (n is Map && (n['foto_nota'] != null || n['url'] != null))
              ...extractUrls(n['foto_nota'] ?? n['url'])
            else if (n is String && n.isNotEmpty)
              n,
      ],
      fotoHasilUrls: [
        if (hasilFotos is List)
          for (final h in hasilFotos)
            if (h is Map && (h['url'] != null || h['foto'] != null))
              (h['url'] ?? h['foto']).toString()
            else if (h is String && h.isNotEmpty)
              h,
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
      namaBarang:
          json['nama_item']?.toString() ?? json['nama']?.toString() ?? '',
      jumlah: parseNum(json['jumlah']) ?? parseNum(json['qty']) ?? 1.0,
      satuan: json['satuan']?.toString(),
      hargaSatuan: parseNum(json['harga_satuan']),
      totalHarga: parseNum(json['total_harga']),
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
            if (e is Map) ServisArmada.fromJson(Map<String, dynamic>.from(e)),
      ],
      currentPage: parseInt(map['current_page']) ?? 1,
      lastPage: parseInt(map['last_page']) ?? 1,
      total: parseInt(map['total']) ?? 0,
    );
  }
}
