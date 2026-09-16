import 'inventory_models.dart';

/// Filter & sort daftar stok sesuai filter UI.
///
/// - [query] dipadankan case-insensitive terhadap nama & kategori.
/// - [kategori] bila non-null & bukan 'Semua', hanya tampilkan kategori itu.
/// - [hanyaRendah] bila true, hanya tampilkan item stok rendah.
/// - [rendahDulu] bila true, item stok rendah muncul di atas (stabil sort).
List<InventoryItem> filterStok(
  List<InventoryItem> items, {
  String query = '',
  String? kategori,
  bool hanyaRendah = false,
  bool rendahDulu = false,
}) {
  final q = query.toLowerCase();
  var result = items.where((item) {
    final matchSearch =
        q.isEmpty ||
        item.nama.toLowerCase().contains(q) ||
        item.kategori.toLowerCase().contains(q);
    final matchKategori =
        kategori == null || kategori == 'Semua' || item.kategori == kategori;
    final matchRendah = !hanyaRendah || item.isStokRendah;
    return matchSearch && matchKategori && matchRendah;
  }).toList();

  if (rendahDulu) {
    result.sort((a, b) {
      if (a.isStokRendah != b.isStokRendah) {
        return a.isStokRendah ? -1 : 1;
      }
      return a.nama.compareTo(b.nama);
    });
  } else {
    result.sort((a, b) => a.nama.compareTo(b.nama));
  }

  return result;
}

/// Detail item opname yang memiliki selisih (untuk review dialog).
class OpnameSelisihItem {
  const OpnameSelisihItem({
    required this.namaBarang,
    required this.sistem,
    required this.fisik,
    required this.selisih,
    this.catatan,
  });

  final String namaBarang;
  final int sistem;
  final int fisik;
  final int selisih;
  final String? catatan;
}

/// Ringkasan review opname.
class OpnameReview {
  const OpnameReview({
    required this.totalDihitung,
    required this.selisihItems,
  });

  final int totalDihitung;
  final List<OpnameSelisihItem> selisihItems;
}

/// Hitung ringkasan review opname — murni, tanpa side-effect.
OpnameReview opnameReview(
  List<OpnameItem> items,
  Map<String, int?> fisikValues,
  Map<String, String?> catatanMap,
) {
  final selisih = <OpnameSelisihItem>[];
  for (final item in items) {
    final fisik = fisikValues[item.id];
    if (fisik == null) continue;
    if (fisik != item.jumlahSistem) {
      selisih.add(
        OpnameSelisihItem(
          namaBarang: item.namaBarang,
          sistem: item.jumlahSistem,
          fisik: fisik,
          selisih: fisik - item.jumlahSistem,
          catatan: catatanMap[item.id],
        ),
      );
    }
  }
  return OpnameReview(
    totalDihitung: fisikValues.values.where((v) => v != null).length,
    selisihItems: selisih,
  );
}

/// Bangun list [OpnameSubmitItem] dari input fisik — murni.
List<OpnameSubmitItem> opnameSubmitItems(
  List<OpnameItem> items,
  Map<String, int?> fisikValues,
  Map<String, String?> catatanMap,
) {
  return [
    for (final item in items)
      if (fisikValues[item.id] != null)
        OpnameSubmitItem(
          bahanBakuId: item.id,
          saldoFisik: fisikValues[item.id]!,
          catatan: catatanMap[item.id],
        ),
  ];
}

/// ID item dalam request yang belum tersedia — dipakai untuk per-item proses.
List<String> outstandingRequestItemIds(InventoryRequest request) {
  return [
    for (final item in request.items)
      if (item.status != InventoryRequestItemStatus.tersedia) item.id,
  ];
}
