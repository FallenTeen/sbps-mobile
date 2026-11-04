/// Model-model modul Security & Keamanan (Section 27, TD-F).
library;

import '../../../core/json_num.dart';

/// Jenis kendaraan tamu (TD-F2).
enum KendaraanTamu {
  tanpaKendaraan('Tanpa Kendaraan'),
  motor('Motor'),
  mobil('Mobil'),
  truk('Truk'),
  lainnya('Lainnya');

  const KendaraanTamu(this.label);
  final String label;

  static KendaraanTamu fromString(String? val) {
    return KendaraanTamu.values.firstWhere(
      (k) => k.name.toLowerCase() == val?.toLowerCase() || k.label.toLowerCase() == val?.toLowerCase(),
      orElse: () => KendaraanTamu.tanpaKendaraan,
    );
  }
}

/// Catatan Buku Tamu (TD-F2).
class BukuTamuRecord {
  const BukuTamuRecord({
    required this.id,
    required this.nama,
    required this.jumlahOrang,
    required this.asal,
    this.nomorTelepon,
    this.kendaraan = KendaraanTamu.tanpaKendaraan,
    this.platNomor,
    this.fotoUrl,
    required this.jamMasuk,
    this.jamKeluar,
    this.catatan,
    this.status = 'masuk',
  });

  final String id;
  final String nama;
  final int jumlahOrang;
  final String asal;
  final String? nomorTelepon;
  final KendaraanTamu kendaraan;
  final String? platNomor;
  final String? fotoUrl;
  final DateTime jamMasuk;
  final DateTime? jamKeluar;
  final String? catatan;
  final String status; // 'masuk' | 'keluar'

  bool get isSudahKeluar => status == 'keluar' || jamKeluar != null;

  BukuTamuRecord copyWith({
    String? status,
    DateTime? jamKeluar,
  }) => BukuTamuRecord(
    id: id,
    nama: nama,
    jumlahOrang: jumlahOrang,
    asal: asal,
    nomorTelepon: nomorTelepon,
    kendaraan: kendaraan,
    platNomor: platNomor,
    fotoUrl: fotoUrl,
    jamMasuk: jamMasuk,
    jamKeluar: jamKeluar ?? this.jamKeluar,
    catatan: catatan,
    status: status ?? this.status,
  );

  factory BukuTamuRecord.fromJson(Map<String, dynamic> json) => BukuTamuRecord(
    id: json['id']?.toString() ?? '',
    nama: json['nama']?.toString() ?? '',
    jumlahOrang: parseInt(json['jumlah_orang']) ?? 1,
    asal: json['asal']?.toString() ?? json['instansi']?.toString() ?? '-',
    nomorTelepon: json['nomor_telepon']?.toString() ?? json['telepon']?.toString(),
    kendaraan: KendaraanTamu.fromString(json['kendaraan']?.toString()),
    platNomor: json['plat_nomor']?.toString(),
    fotoUrl: json['foto_url']?.toString() ?? json['foto']?.toString(),
    jamMasuk: DateTime.tryParse(json['jam_masuk']?.toString() ?? json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    jamKeluar: DateTime.tryParse(json['jam_keluar']?.toString() ?? ''),
    catatan: json['catatan']?.toString(),
    status: json['status']?.toString() ?? (json['jam_keluar'] != null ? 'keluar' : 'masuk'),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'jumlah_orang': jumlahOrang,
    'asal': asal,
    'nomor_telepon': nomorTelepon,
    'kendaraan': kendaraan.name,
    'plat_nomor': platNomor,
    'foto_url': fotoUrl,
    'jam_masuk': jamMasuk.toIso8601String(),
    'jam_keluar': jamKeluar?.toIso8601String(),
    'catatan': catatan,
    'status': status,
  };
}

/// Item checklist kantor (TD-F3).
class ChecklistKantorItem {
  ChecklistKantorItem({
    required this.id,
    required this.label,
    this.isChecked = false,
    this.catatan,
    this.fotoPath,
  });

  final String id;
  final String label;
  bool isChecked;
  String? catatan;
  String? fotoPath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'is_checked': isChecked,
    'catatan': catatan,
    'foto_path': fotoPath,
  };

  factory ChecklistKantorItem.fromJson(Map<String, dynamic> json) => ChecklistKantorItem(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    isChecked: json['is_checked'] == true,
    catatan: json['catatan']?.toString(),
    fotoPath: json['foto_path']?.toString(),
  );
}

/// Laporan Darurat (TD-F4).
class LaporanDaruratRecord {
  const LaporanDaruratRecord({
    required this.id,
    required this.kategori,
    required this.judul,
    required this.deskripsi,
    required this.lokasiRuangan,
    required this.tingkat,
    this.fotoUrls = const [],
    required this.createdAt,
  });

  final String id;
  final String kategori;
  final String judul;
  final String deskripsi;
  final String lokasiRuangan;
  final String tingkat; // 'siaga' | 'darurat' | 'kritis'
  final List<String> fotoUrls;
  final DateTime createdAt;

  factory LaporanDaruratRecord.fromJson(Map<String, dynamic> json) => LaporanDaruratRecord(
    id: json['id']?.toString() ?? '',
    kategori: json['kategori']?.toString() ?? 'Lainnya',
    judul: json['judul']?.toString() ?? '',
    deskripsi: json['deskripsi']?.toString() ?? '',
    lokasiRuangan: json['lokasi_ruangan']?.toString() ?? json['lokasi']?.toString() ?? '',
    tingkat: json['tingkat']?.toString() ?? 'darurat',
    fotoUrls: (json['foto_urls'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
  );
}
