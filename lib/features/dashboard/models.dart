/// Model Dashboard & Chart — docs/api-mobile.md §12.
///
/// Semua parser toleran terhadap field yang hilang / bentuk berbeda,
/// karena sebagian nilai bisa null dari backend.
library;

class TitikOverview {
  const TitikOverview({
    required this.titikId,
    required this.titik,
    required this.proyek,
    this.latitude,
    this.longitude,
    this.sdmCount = 0,
    this.armadaCount = 0,
    this.presensiToday = 0,
    this.produksiToday = 0,
  });

  final String titikId;
  final String titik;
  final String proyek;
  final double? latitude;
  final double? longitude;
  final int sdmCount;
  final int armadaCount;
  final int presensiToday;

  /// Total output produksi hari ini.
  final double produksiToday;

  factory TitikOverview.fromJson(Map<String, dynamic> json) => TitikOverview(
    titikId: json['titik_id']?.toString() ?? '',
    titik: json['titik']?.toString() ?? '-',
    proyek: json['proyek']?.toString() ?? '-',
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    sdmCount: (json['sdm_count'] as num?)?.toInt() ?? 0,
    armadaCount: (json['armada_count'] as num?)?.toInt() ?? 0,
    presensiToday: (json['presensi_today'] as num?)?.toInt() ?? 0,
    produksiToday: (json['produksi_today'] as num?)?.toDouble() ?? 0,
  );
}

class DashboardOverview {
  const DashboardOverview({
    required this.tanggal,
    required this.totalTitik,
    required this.items,
  });

  final String tanggal;
  final int totalTitik;
  final List<TitikOverview> items;

  factory DashboardOverview.fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return DashboardOverview(
      tanggal: map['tanggal']?.toString() ?? '',
      totalTitik: (map['total_titik'] as num?)?.toInt() ?? 0,
      items: [
        if (list is List)
          for (final e in list)
            TitikOverview.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail titik
// ---------------------------------------------------------------------------

class SdmItem {
  const SdmItem({required this.nama, this.jabatan});

  final String nama;
  final String? jabatan;
}

class ArmadaItem {
  const ArmadaItem({
    required this.kodeUnit,
    this.platNomor,
    this.jenis,
    this.status,
  });

  final String kodeUnit;
  final String? platNomor;
  final String? jenis;
  final String? status;
}

class PresensiRow {
  const PresensiRow({required this.nama, this.checkIn, this.checkOut});

  final String nama;
  final DateTime? checkIn;
  final DateTime? checkOut;
}

class RabInfo {
  const RabInfo({
    required this.totalRencana,
    required this.totalRealisasi,
    required this.persentase,
  });

  final double totalRencana;
  final double totalRealisasi;
  final double persentase;
}

class ProduksiHariIniInfo {
  const ProduksiHariIniInfo({this.totalOutput = 0, this.jumlahSesi = 0});

  final double totalOutput;
  final int jumlahSesi;
}

class TitikDetail {
  const TitikDetail({
    required this.titikNama,
    required this.proyek,
    required this.status,
    this.latitude,
    this.longitude,
    required this.sdm,
    required this.armada,
    required this.produksiHariIni,
    required this.presensiHariIni,
    this.rab,
  });

  final String titikNama;
  final String proyek;
  final String status;
  final double? latitude;
  final double? longitude;
  final List<SdmItem> sdm;
  final List<ArmadaItem> armada;
  final ProduksiHariIniInfo produksiHariIni;
  final List<PresensiRow> presensiHariIni;
  final RabInfo? rab;

  factory TitikDetail.fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final titik = map['titik'] is Map
        ? Map<String, dynamic>.from(map['titik'])
        : const {};

    List<Map<String, dynamic>> listOf(Object? raw) => [
      if (raw is List)
        for (final e in raw)
          if (e is Map) Map<String, dynamic>.from(e),
    ];

    DateTime? dt(Object? raw) => raw == null || raw.toString().isEmpty
        ? null
        : DateTime.tryParse(raw.toString());

    final prodMap = map['produksi_hari_ini'] is Map
        ? Map<String, dynamic>.from(map['produksi_hari_ini'])
        : const {};
    final rabMap = map['rab'] is Map
        ? Map<String, dynamic>.from(map['rab'])
        : null;

    return TitikDetail(
      titikNama: titik['nama']?.toString() ?? '-',
      proyek: titik['proyek']?.toString() ?? '-',
      status: titik['status']?.toString() ?? '-',
      latitude: (titik['latitude'] as num?)?.toDouble(),
      longitude: (titik['longitude'] as num?)?.toDouble(),
      sdm: [
        for (final e in listOf(map['sdm']))
          SdmItem(
            nama: e['nama']?.toString() ?? '-',
            jabatan: e['jabatan']?.toString(),
          ),
      ],
      armada: [
        for (final e in listOf(map['armada']))
          ArmadaItem(
            kodeUnit: e['kode_unit']?.toString() ?? '-',
            platNomor: e['plat_nomor']?.toString(),
            jenis: e['jenis']?.toString(),
            status: e['status']?.toString(),
          ),
      ],
      produksiHariIni: ProduksiHariIniInfo(
        totalOutput: (prodMap['total_output'] as num?)?.toDouble() ?? 0,
        jumlahSesi: (prodMap['jumlah_sesi'] as num?)?.toInt() ?? 0,
      ),
      presensiHariIni: [
        for (final e in listOf(map['presensi_hari_ini']))
          PresensiRow(
            nama: e['nama']?.toString() ?? '-',
            checkIn: dt(e['check_in']),
            checkOut: dt(e['check_out']),
          ),
      ],
      rab: rabMap == null
          ? null
          : RabInfo(
              totalRencana: (rabMap['total_rencana'] as num?)?.toDouble() ?? 0,
              totalRealisasi:
                  (rabMap['total_realisasi'] as num?)?.toDouble() ?? 0,
              persentase: (rabMap['persentase'] as num?)?.toDouble() ?? 0,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart mingguan
// ---------------------------------------------------------------------------

class ProduksiChartPoint {
  const ProduksiChartPoint({
    required this.minggu,
    required this.totalOutput,
    required this.jumlahSesi,
  });

  /// Tanggal awal minggu (YYYY-MM-DD).
  final String minggu;
  final double totalOutput;
  final int jumlahSesi;
}

class ProduksiChart {
  const ProduksiChart({
    required this.bulan,
    required this.tahun,
    required this.items,
  });

  final int bulan;
  final int tahun;
  final List<ProduksiChartPoint> items;

  factory ProduksiChart.fromRaw(Object? raw, {int? bulan, int? tahun}) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return ProduksiChart(
      bulan: (map['bulan'] as num?)?.toInt() ?? bulan ?? 1,
      tahun: (map['tahun'] as num?)?.toInt() ?? tahun ?? 1,
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map)
              () {
                final m = Map<String, dynamic>.from(e);
                return ProduksiChartPoint(
                  minggu: m['minggu']?.toString() ?? '',
                  totalOutput: (m['total_output'] as num?)?.toDouble() ?? 0,
                  jumlahSesi: (m['jumlah_sesi'] as num?)?.toInt() ?? 0,
                );
              }(),
      ],
    );
  }
}

class KeuanganChartPoint {
  const KeuanganChartPoint({
    required this.minggu,
    required this.masuk,
    required this.keluar,
  });

  final String minggu;
  final double masuk;
  final double keluar;
}

class KeuanganChart {
  const KeuanganChart({
    required this.bulan,
    required this.tahun,
    required this.items,
  });

  final int bulan;
  final int tahun;
  final List<KeuanganChartPoint> items;

  factory KeuanganChart.fromRaw(Object? raw, {int? bulan, int? tahun}) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return KeuanganChart(
      bulan: (map['bulan'] as num?)?.toInt() ?? bulan ?? 1,
      tahun: (map['tahun'] as num?)?.toInt() ?? tahun ?? 1,
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map)
              () {
                final m = Map<String, dynamic>.from(e);
                return KeuanganChartPoint(
                  minggu: m['minggu']?.toString() ?? '',
                  masuk: (m['masuk'] as num?)?.toDouble() ?? 0,
                  keluar: (m['keluar'] as num?)?.toDouble() ?? 0,
                );
              }(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ringkasan lainnya
// ---------------------------------------------------------------------------

class ArmadaStatusData {
  const ArmadaStatusData({required this.total, required this.items});

  final int total;

  /// Pasangan (status, jumlah).
  final List<({String status, int jumlah})> items;

  factory ArmadaStatusData.fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return ArmadaStatusData(
      total: (map['total'] as num?)?.toInt() ?? 0,
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map)
              (
                status:
                    Map<String, dynamic>.from(e)['status']?.toString() ?? '-',
                jumlah:
                    (Map<String, dynamic>.from(e)['jumlah'] as num?)?.toInt() ??
                    0,
              ),
      ],
    );
  }
}

class KehadiranDivisiData {
  const KehadiranDivisiData({
    required this.tanggal,
    required this.totalHadir,
    required this.items,
  });

  final String tanggal;
  final int totalHadir;

  /// Pasangan (divisi, hadir, sudah check-out).
  final List<({String divisi, int hadir, int checkOut})> items;

  factory KehadiranDivisiData.fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return KehadiranDivisiData(
      tanggal: map['tanggal']?.toString() ?? '',
      totalHadir: (map['total_hadir'] as num?)?.toInt() ?? 0,
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map)
              (
                divisi:
                    Map<String, dynamic>.from(e)['divisi']?.toString() ?? '-',
                hadir:
                    (Map<String, dynamic>.from(e)['hadir'] as num?)?.toInt() ??
                    0,
                checkOut:
                    (Map<String, dynamic>.from(e)['check_out'] as num?)
                        ?.toInt() ??
                    0,
              ),
      ],
    );
  }
}

class PoPendingPage {
  const PoPendingPage({required this.total, required this.items});

  final int total;
  final List<Map<String, dynamic>> items;

  bool get cappedAtLimit => items.length >= 20;

  static PoPendingPage fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return PoPendingPage(
      total: (map['total'] as num?)?.toInt() ?? 0,
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map) Map<String, dynamic>.from(e),
      ],
    );
  }
}

class InvoicePendingPage {
  const InvoicePendingPage({required this.total, required this.items});

  final int total;
  final List<Map<String, dynamic>> items;

  bool get cappedAtLimit => items.length >= 20;

  static InvoicePendingPage fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return InvoicePendingPage(
      total: (map['total'] as num?)?.toInt() ?? 0,
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map) Map<String, dynamic>.from(e),
      ],
    );
  }
}
