/// Model master untuk halaman Mulai Sesi Produksi (GET /master/*).
class MesinMaster {
  const MesinMaster({
    required this.id,
    required this.nama,
    this.jenis,
    this.kapasitas,
    this.titikId,
    this.titikNama,
    this.produkDefaultId,
    this.produkDefaultNama,
  });

  final String id;
  final String nama;
  final String? jenis;
  final double? kapasitas;
  final String? titikId;
  final String? titikNama;
  final String? produkDefaultId;
  final String? produkDefaultNama;

  factory MesinMaster.fromJson(Map<String, dynamic> json) {
    final titik = json['titik'];
    final produk = json['produk_default'];
    return MesinMaster(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      jenis: json['jenis']?.toString(),
      kapasitas: (json['kapasitas'] as num?)?.toDouble(),
      titikId: titik is Map ? titik['id']?.toString() : null,
      titikNama: titik is Map ? titik['nama']?.toString() : null,
      produkDefaultId: produk is Map ? produk['id']?.toString() : null,
      produkDefaultNama: produk is Map ? produk['nama']?.toString() : null,
    );
  }
}

class ProdukMaster {
  const ProdukMaster({
    required this.id,
    required this.nama,
    this.kategori,
    this.satuanOutput,
  });

  final String id;
  final String nama;
  final String? kategori;
  final String? satuanOutput;

  factory ProdukMaster.fromJson(Map<String, dynamic> json) {
    return ProdukMaster(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      kategori: json['kategori']?.toString(),
      satuanOutput: json['satuan_output']?.toString(),
    );
  }
}

class BahanBakuMaster {
  const BahanBakuMaster({
    required this.id,
    required this.nama,
    this.kode,
    this.satuan,
  });

  final String id;
  final String nama;
  final String? kode;
  final String? satuan;

  factory BahanBakuMaster.fromJson(Map<String, dynamic> json) {
    return BahanBakuMaster(
      id: json['id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      kode: json['kode']?.toString(),
      satuan: json['satuan']?.toString(),
    );
  }
}
