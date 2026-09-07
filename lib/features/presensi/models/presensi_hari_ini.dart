import 'titik.dart';

/// Status presensi hari ini dari GET /presensi/hari-ini.
enum PresensiStatus { belumCheckIn, menungguCheckOut, selesai }

/// Ringkasan presensi hari ini.
///
/// Saat `belum_check_in`, backend tetap mengirim objek dengan field null —
/// diparse menjadi [PresensiStatus.belumCheckIn] dengan field kosong.
class PresensiHariIni {
  const PresensiHariIni({
    required this.status,
    this.presensiId,
    this.checkIn,
    this.checkOut,
    this.statusValidasi,
    this.titik,
    this.formulir,
  });

  final PresensiStatus status;
  final String? presensiId;

  /// ISO-8601 dari backend.
  final String? checkIn;
  final String? checkOut;

  /// `valid` | `luar_radius`.
  final String? statusValidasi;
  final Titik? titik;
  final Map<String, dynamic>? formulir;

  bool get luarRadius => statusValidasi == 'luar_radius';

  static PresensiHariIni fromJson(Object? raw) {
    if (raw is! Map) {
      return const PresensiHariIni(status: PresensiStatus.belumCheckIn);
    }
    final json = Map<String, dynamic>.from(raw);
    final rawStatus =
        (json['status'] as String?)?.trim().toLowerCase() ?? 'belum_check_in';
    final status = switch (rawStatus) {
      'menunggu_check_out' => PresensiStatus.menungguCheckOut,
      'selesai' => PresensiStatus.selesai,
      _ => PresensiStatus.belumCheckIn,
    };
    return PresensiHariIni(
      status: status,
      presensiId: json['presensi_id']?.toString(),
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      statusValidasi: json['status_validasi'] as String?,
      titik: Titik.tryParse(json['titik']),
      formulir: json['formulir'] == null
          ? null
          : Map<String, dynamic>.from(json['formulir'] as Map),
    );
  }
}

/// Satu baris riwayat presensi (GET /presensi/riwayat → data.items[]).
class RiwayatPresensi {
  const RiwayatPresensi({
    required this.id,
    this.tanggal,
    this.checkIn,
    this.checkOut,
    this.status,
    this.statusValidasi,
    this.namaTitik,
  });

  final String id;
  final String? tanggal;
  final String? checkIn;
  final String? checkOut;
  final String? status;
  final String? statusValidasi;
  final String? namaTitik;

  static RiwayatPresensi fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('riwayat item tidak valid');
    final json = Map<String, dynamic>.from(raw);
    final titikJson = json['titik'];
    return RiwayatPresensi(
      id: json['presensi_id']?.toString() ?? '',
      tanggal: json['tanggal'] as String?,
      checkIn: json['check_in'] as String?,
      checkOut: json['check_out'] as String?,
      status: json['status'] as String?,
      statusValidasi: json['status_validasi'] as String?,
      namaTitik:
          titikJson is Map ? titikJson['nama']?.toString() : null,
    );
  }
}

/// Halaman riwayat: items[] + pagination.
class RiwayatPresensiPage {
  const RiwayatPresensiPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  final List<RiwayatPresensi> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  static RiwayatPresensiPage fromJson(Object? raw) {
    if (raw is! Map) {
      return const RiwayatPresensiPage(items: [], currentPage: 1, lastPage: 1);
    }
    final json = Map<String, dynamic>.from(raw);
    final pagination =
        json['pagination'] is Map ? Map<String, dynamic>.from(json['pagination'] as Map) : <String, dynamic>{};
    final itemsRaw = json['items'];
    return RiwayatPresensiPage(
      items: itemsRaw is List
          ? itemsRaw.map(RiwayatPresensi.fromJson).toList()
          : [],
      currentPage: (pagination['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (pagination['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}
