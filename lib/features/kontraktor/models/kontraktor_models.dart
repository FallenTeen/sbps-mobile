/// Model-model untuk Portal Kontraktor (Proyek Kontrak, Invoice, Komunikasi Log).
library;

import '../../../core/json_num.dart';

class ProyekKontrakItem {
  const ProyekKontrakItem({
    required this.id,
    required this.kodeProyek,
    required this.nama,
    this.client,
    this.lokasi,
    required this.status,
    this.unitBisnis,
    this.tanggalMulai,
  });

  final String id;
  final String kodeProyek;
  final String nama;
  final String? client;
  final String? lokasi;
  final String status;
  final String? unitBisnis;
  final String? tanggalMulai;

  factory ProyekKontrakItem.fromJson(Map<String, dynamic> json) {
    return ProyekKontrakItem(
      id: json['id']?.toString() ?? '',
      kodeProyek: json['kode_proyek']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      client: json['client']?.toString(),
      lokasi: json['lokasi']?.toString(),
      status: json['status']?.toString() ?? '',
      unitBisnis: json['unit_bisnis']?.toString(),
      tanggalMulai: json['tanggal_mulai']?.toString(),
    );
  }
}

class InvoiceKontrakItem {
  const InvoiceKontrakItem({
    required this.id,
    required this.kodeInvoice,
    this.proyek,
    this.tanggalTerbit,
    this.tanggalJatuhTempo,
    required this.status,
    required this.total,
    required this.paid,
    required this.sisa,
  });

  final String id;
  final String kodeInvoice;
  final String? proyek;
  final String? tanggalTerbit;
  final String? tanggalJatuhTempo;
  final String status;
  final double total;
  final double paid;
  final double sisa;

  factory InvoiceKontrakItem.fromJson(Map<String, dynamic> json) {
    return InvoiceKontrakItem(
      id: json['id']?.toString() ?? '',
      kodeInvoice: json['kode_invoice']?.toString() ?? '',
      proyek: json['proyek']?.toString(),
      tanggalTerbit: json['tanggal_terbit']?.toString(),
      tanggalJatuhTempo: json['tanggal_jatuh_tempo']?.toString(),
      status: json['status']?.toString() ?? '',
      total: parseNum(json['total']) ?? 0.0,
      paid: parseNum(json['paid']) ?? 0.0,
      sisa: parseNum(json['sisa']) ?? 0.0,
    );
  }
}

class ProduksiSummaryItem {
  const ProduksiSummaryItem({
    required this.nama,
    required this.satuan,
    required this.totalOutput,
    required this.sesiCount,
  });

  final String nama;
  final String satuan;
  final double totalOutput;
  final int sesiCount;

  factory ProduksiSummaryItem.fromJson(Map<String, dynamic> json) {
    return ProduksiSummaryItem(
      nama: json['nama']?.toString() ?? '',
      satuan: json['satuan']?.toString() ?? '',
      totalOutput: parseNum(json['total_output']) ?? 0.0,
      sesiCount: parseInt(json['sesi_count']) ?? 0,
    );
  }
}

class KomunikasiLogItem {
  const KomunikasiLogItem({
    required this.id,
    required this.pengirim,
    required this.pengirimRole,
    required this.pesan,
    this.waktu,
  });

  final String id;
  final String pengirim;
  final String pengirimRole;
  final String pesan;
  final String? waktu;

  factory KomunikasiLogItem.fromJson(Map<String, dynamic> json) {
    return KomunikasiLogItem(
      id: json['id']?.toString() ?? '',
      pengirim: json['pengirim']?.toString() ?? '',
      pengirimRole: json['pengirim_role']?.toString() ?? '',
      pesan: json['pesan']?.toString() ?? '',
      waktu: json['waktu']?.toString(),
    );
  }
}

class DetailProyekKontrak {
  const DetailProyekKontrak({
    required this.proyek,
    required this.produksiSummary,
    required this.totalRencana,
    required this.totalRealisasi,
    required this.persentaseRab,
    required this.invoices,
    required this.komunikasiLogs,
  });

  final ProyekKontrakItem proyek;
  final List<ProduksiSummaryItem> produksiSummary;
  final double totalRencana;
  final double totalRealisasi;
  final double persentaseRab;
  final List<InvoiceKontrakItem> invoices;
  final List<KomunikasiLogItem> komunikasiLogs;

  factory DetailProyekKontrak.fromJson(Map<String, dynamic> json) {
    final proyekMap = json['proyek'] is Map
        ? Map<String, dynamic>.from(json['proyek'] as Map)
        : const <String, dynamic>{};
    final rabMap = json['rab_agregat'] is Map
        ? Map<String, dynamic>.from(json['rab_agregat'] as Map)
        : const <String, dynamic>{};
    final prodList = json['produksi_summary'];
    final invList = json['invoices'];
    final komList = json['komunikasi_logs'];

    return DetailProyekKontrak(
      proyek: ProyekKontrakItem.fromJson(proyekMap),
      produksiSummary: [
        if (prodList is List)
          for (final p in prodList)
            if (p is Map)
              ProduksiSummaryItem.fromJson(Map<String, dynamic>.from(p)),
      ],
      totalRencana: parseNum(rabMap['total_rencana']) ?? 0.0,
      totalRealisasi: parseNum(rabMap['total_realisasi']) ?? 0.0,
      persentaseRab: parseNum(rabMap['persentase']) ?? 0.0,
      invoices: [
        if (invList is List)
          for (final i in invList)
            if (i is Map)
              InvoiceKontrakItem.fromJson(Map<String, dynamic>.from(i)),
      ],
      komunikasiLogs: [
        if (komList is List)
          for (final k in komList)
            if (k is Map)
              KomunikasiLogItem.fromJson(Map<String, dynamic>.from(k)),
      ],
    );
  }
}
