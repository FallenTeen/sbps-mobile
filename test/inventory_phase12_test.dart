import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/inventory/inventory_models.dart';
import 'package:sbps_mobile/features/inventory/inventory_rules.dart'
    as rules;

InventoryItem _stok({
  String id = 'm1',
  String nama = 'Oli Mesin',
  String kategori = 'Sparepart',
  int stokSaatIni = 10,
  int stokMinimum = 5,
  String? lokasiGudang,
}) {
  return InventoryItem(
    id: id,
    nama: nama,
    kategori: kategori,
    stokSaatIni: stokSaatIni,
    stokMinimum: stokMinimum,
    satuan: 'L',
    lokasiGudang: lokasiGudang,
  );
}

OpnameItem _opname({
  String id = 'o1',
  String nama = 'Oli Mesin',
  int sistem = 10,
}) {
  return OpnameItem(
    id: id,
    namaBarang: nama,
    kategori: 'Sparepart',
    jumlahSistem: sistem,
    satuan: 'L',
  );
}

void main() {
  group('Business rule stok — isStokRendah tidak berubah', () {
    test('stok saat ini < minimum = rendah', () {
      final item = _stok(stokSaatIni: 4, stokMinimum: 5);
      expect(item.isStokRendah, isTrue);
    });

    test('stok saat ini == minimum = aman', () {
      final item = _stok(stokSaatIni: 5, stokMinimum: 5);
      expect(item.isStokRendah, isFalse);
    });

    test('stok saat ini > minimum = aman', () {
      final item = _stok(stokSaatIni: 7, stokMinimum: 5);
      expect(item.isStokRendah, isFalse);
    });
  });

  group('filterStok — pencarian', () {
    test('query kosong mengembalikan semua', () {
      final items = [_stok(nama: 'Oli'), _stok(id: 'm2', nama: 'Ban')];
      expect(rules.filterStok(items).length, 2);
    });

    test('query mencocokkan nama case-insensitive', () {
      final items = [_stok(nama: 'Oli Mesin'), _stok(id: 'm2', nama: 'Ban')];
      final result = rules.filterStok(items, query: 'oli');
      expect(result.length, 1);
      expect(result.single.nama, 'Oli Mesin');
    });

    test('query mencocokkan kategori', () {
      final items = [
        _stok(id: 'm1', nama: 'Semen', kategori: 'Bahan Baku'),
        _stok(id: 'm2', nama: 'Oli', kategori: 'Sparepart'),
      ];
      final result = rules.filterStok(items, query: 'spare');
      expect(result.length, 1);
      expect(result.single.nama, 'Oli');
    });
  });

  group('filterStok — kategori', () {
    test('kategori null/Semua menampilkan semua', () {
      final items = [
        _stok(id: 'm1', kategori: 'Bahan Baku'),
        _stok(id: 'm2', kategori: 'Sparepart'),
      ];
      expect(rules.filterStok(items, kategori: null).length, 2);
      expect(rules.filterStok(items, kategori: 'Semua').length, 2);
    });

    test('kategori spesifik menyaring', () {
      final items = [
        _stok(id: 'm1', kategori: 'Bahan Baku'),
        _stok(id: 'm2', kategori: 'Sparepart'),
      ];
      final result = rules.filterStok(items, kategori: 'Sparepart');
      expect(result.length, 1);
      expect(result.single.id, 'm2');
    });
  });

  group('filterStok — stok rendah (filter + sort)', () {
    test('hanyaRendah menampilkan item di bawah minimum saja', () {
      final items = [
        _stok(id: 'aman', stokSaatIni: 10, stokMinimum: 5),
        _stok(id: 'rendah', stokSaatIni: 2, stokMinimum: 5),
      ];
      final result = rules.filterStok(items, hanyaRendah: true);
      expect(result.length, 1);
      expect(result.single.id, 'rendah');
    });

    test('rendahDulu menaruh item rendah di atas, stabil per nama', () {
      final items = [
        _stok(id: 'a', nama: 'Aman', stokSaatIni: 10, stokMinimum: 5),
        _stok(id: 'b', nama: 'Brendah', stokSaatIni: 2, stokMinimum: 5),
        _stok(id: 'c', nama: 'Caman', stokSaatIni: 10, stokMinimum: 5),
      ];
      final result = rules.filterStok(items, rendahDulu: true);
      expect(result.first.id, 'b');
      expect(result.map((i) => i.id).toList(), ['b', 'a', 'c']);
    });

    test('kombinasi filter + sort + search', () {
      final items = [
        _stok(id: 'a', nama: 'Oli A', stokSaatIni: 10, stokMinimum: 5),
        _stok(
          id: 'b',
          nama: 'Oli B',
          stokSaatIni: 2,
          stokMinimum: 5,
          kategori: 'Bahan Baku',
        ),
        _stok(id: 'c', nama: 'Oli C', stokSaatIni: 1, stokMinimum: 5),
      ];
      final result = rules.filterStok(
        items,
        query: 'oli',
        kategori: 'Sparepart',
        hanyaRendah: true,
        rendahDulu: true,
      );
      expect(result.length, 1);
      expect(result.single.id, 'c');
    });
  });

  group('opnameReview — fisik vs sistem', () {
    test('fisik kosong tidak dihitung', () {
      final review = rules.opnameReview(
        [_opname(sistem: 10)],
        const {'o1': null},
        const {},
      );
      expect(review.totalDihitung, 0);
      expect(review.selisihItems, isEmpty);
    });

    test('fisik sama dengan sistem = tidak selisih', () {
      final review = rules.opnameReview(
        [_opname(sistem: 10)],
        const {'o1': 10},
        const {},
      );
      expect(review.totalDihitung, 1);
      expect(review.selisihItems, isEmpty);
    });

    test('selisih dihitung dengan benar (positif & negatif)', () {
      final review = rules.opnameReview(
        [
          _opname(id: 'o1', sistem: 10),
          _opname(id: 'o2', sistem: 4),
          _opname(id: 'o3', sistem: 7),
        ],
        const {'o1': 12, 'o2': 4, 'o3': 5},
        const {},
      );
      expect(review.totalDihitung, 3);
      expect(review.selisihItems.length, 2);
      expect(review.selisihItems[0].selisih, 2);
      expect(review.selisihItems[1].selisih, -2);
    });

    test('catatan ikut terbawa ke review', () {
      final review = rules.opnameReview(
        [_opname(sistem: 10)],
        const {'o1': 8},
        const {'o1': 'Tambah dikit'},
      );
      expect(review.selisihItems.single.catatan, 'Tambah dikit');
    });
  });

  group('opnameSubmitItems — payload outbox', () {
    test('hanya item dengan nilai fisik yang dikirim', () {
      final items = rules.opnameSubmitItems(
        [_opname(id: 'o1'), _opname(id: 'o2')],
        const {'o1': 9},
        const {},
      );
      expect(items.length, 1);
      expect(items.single.bahanBakuId, 'o1');
      expect(items.single.saldoFisik, 9);
    });

    test('toJson memakai key snake_case backend', () {
      final items = rules.opnameSubmitItems(
        [_opname(id: 'o1')],
        const {'o1': 9},
        const {'o1': 'Sisa rusak'},
      );
      final json = items.single.toJson();
      expect(json['bahan_baku_id'], 'o1');
      expect(json['saldo_fisik'], 9);
      expect(json['catatan'], 'Sisa rusak');
    });

    test('catatan kosong tidak dikirim ke backend', () {
      final items = rules.opnameSubmitItems(
        [_opname(id: 'o1')],
        const {'o1': 9},
        const {'o1': '   '},
      );
      expect(items.single.toJson().containsKey('catatan'), isFalse);
    });
  });

  group('outstandingRequestItemIds — status per item request', () {
    InventoryRequest buildReq(List<InventoryRequestItem> items) =>
        InventoryRequest(
          id: 'req1',
          workshopJobId: 'j1',
          platNomor: 'B 1234 XYZ',
          kategoriServis: 'rutin',
          status: InventoryRequestStatus.pending,
          items: items,
          createdAt: DateTime(2026, 9, 16),
        );

    InventoryRequestItem buildItem(
      String id, {
      InventoryRequestItemStatus status = InventoryRequestItemStatus.kurang,
      int? jumlahTersedia,
    }) {
      return InventoryRequestItem(
        id: id,
        namaBarang: 'Item $id',
        jumlahDiminta: 4,
        jumlahTersedia: jumlahTersedia,
        satuan: 'L',
        status: status,
      );
    }

    test('item tersedia tidak ikut belum-proses', () {
      final request = buildReq([
        buildItem('a', status: InventoryRequestItemStatus.tersedia),
        buildItem('b', status: InventoryRequestItemStatus.kurang),
        buildItem('c', status: InventoryRequestItemStatus.tidakTersedia),
      ]);
      expect(rules.outstandingRequestItemIds(request), ['b', 'c']);
    });

    test('semua tersedia = daftar kosong', () {
      final request = buildReq([
        buildItem('a', status: InventoryRequestItemStatus.tersedia),
        buildItem('b', status: InventoryRequestItemStatus.tersedia),
      ]);
      expect(rules.outstandingRequestItemIds(request), isEmpty);
    });

    test('item kurang mempertahankan jumlahTersedia parsial', () {
      final item = buildItem(
        'a',
        status: InventoryRequestItemStatus.kurang,
        jumlahTersedia: 2,
      );
      expect(item.jumlahTersedia, 2);
      final request = buildReq([item]);
      expect(rules.outstandingRequestItemIds(request), ['a']);
    });
  });
}