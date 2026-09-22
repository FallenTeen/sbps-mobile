import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/core/json_num.dart';
import 'package:sbps_mobile/features/dashboard/models.dart';

void main() {
  group('parseNum / parseInt — toleran string numerik dari backend Laravel', () {
    test('menerima num langsung', () {
      expect(parseNum(42.5), 42.5);
      expect(parseNum(7), 7.0);
      expect(parseInt(12), 12);
      expect(parseInt(12.9), 12);
    });

    test('menerima string numerik (kolom DECIMAL -> string JSON)', () {
      expect(parseNum('1850000.00'), 1850000.0);
      expect(parseNum('720000.5'), 720000.5);
      expect(parseNum('0'), 0.0);
      expect(parseInt('12'), 12);
      expect(parseNum(' 42.5 '), 42.5);
    });

    test('menolak nilai non-numerik dengan null', () {
      expect(parseNum(null), isNull);
      expect(parseNum(''), isNull);
      expect(parseNum('  '), isNull);
      expect(parseNum(true), isNull);
      expect(parseNum('abc'), isNull);
      expect(parseInt(null), isNull);
      expect(parseInt('abc'), isNull);
    });
  });

  group('KeuanganChart.fromRaw — kontrak finansial string numerik', () {
    test('parsing sukses walau masuk/keluar dikirim sebagai string', () {
      final chart = KeuanganChart.fromRaw({
        'bulan': '9',
        'tahun': '2026',
        'items': [
          {'minggu': '2026-09-01', 'masuk': '1850000.00', 'keluar': '720000.50'},
          {'minggu': '2026-09-08', 'masuk': 0, 'keluar': '125000'},
        ],
      });
      expect(chart.bulan, 9);
      expect(chart.tahun, 2026);
      expect(chart.items.length, 2);
      expect(chart.items[0].masuk, 1850000.0);
      expect(chart.items[0].keluar, 720000.5);
      expect(chart.items[1].masuk, 0);
      expect(chart.items[1].keluar, 125000.0);
      expect(
        chart.items[0],
        isA<KeuanganChartPoint>()
            .having((p) => p.minggu, 'minggu', '2026-09-01'),
      );
    });
  });

  group('PoPendingPage / InvoicePendingPage — total string', () {
    test('PoPendingPage.total string tetap terbaca', () {
      final po = PoPendingPage.fromRaw({
        'total': '3',
        'items': [
          {'kode_po': 'PO-001', 'total': '150000.00'},
          {'kode_po': 'PO-002', 'total': 250000},
        ],
      });
      expect(po.total, 3);
      expect(po.items.length, 2);
      expect(po.items[0]['total'], '150000.00');
    });

    test('InvoicePendingPage.total string tetap terbaca', () {
      final inv = InvoicePendingPage.fromRaw({
        'total': '2',
        'items': [
          {'kode_invoice': 'INV-001', 'sisa': '50000'},
          {'kode_invoice': 'INV-002', 'sisa': 0},
        ],
      });
      expect(inv.total, 2);
      expect(inv.items.length, 2);
    });
  });
}