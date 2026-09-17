import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/dashboard/dashboard_providers.dart';
import 'package:sbps_mobile/features/dashboard/dashboard_rules.dart';

void main() {
  group('dashboardSectionsFor (role awareness)', () {
    test('Owner melihat semua section', () {
      final s = dashboardSectionsFor('Owner');
      expect(s.showOverview, isTrue);
      expect(s.showArmadaStatus, isTrue);
      expect(s.showKehadiran, isTrue);
      expect(s.showChartProduksi, isTrue);
      expect(s.showFinancial, isTrue);
    });

    test('Admin Keuangan = admin-like', () {
      final s = dashboardSectionsFor('Admin Keuangan');
      expect(s.showOverview, isTrue);
      expect(s.showArmadaStatus, isTrue);
      expect(s.showKehadiran, isTrue);
      expect(s.showFinancial, isTrue);
    });

    test('Mandor Titik TIDAK melihat armada (tanpa drill-down = dead-end)', () {
      final s = dashboardSectionsFor('Mandor Titik');
      expect(s.showOverview, isTrue);
      expect(s.showArmadaStatus, isFalse);
      expect(s.showFinancial, isFalse);
      expect(s.showKehadiran, isFalse);
    });

    test('Kepala Divisi Armada melihat overview & armada (punya modul)', () {
      final s = dashboardSectionsFor('Kepala Divisi Armada');
      expect(s.showOverview, isTrue);
      expect(s.showArmadaStatus, isTrue);
      expect(s.showFinancial, isFalse);
    });

    test('Kontraktor hanya overview — bukan angka tanpa tindakan', () {
      final s = dashboardSectionsFor('Kontraktor');
      expect(s.showOverview, isTrue);
      expect(s.showArmadaStatus, isFalse);
      expect(s.showKehadiran, isFalse);
      expect(s.showChartProduksi, isFalse);
      expect(s.showFinancial, isFalse);
    });
  });

  group('attentionItemsFor — angka hanya tampil bila actionable', () {
    const none = AttentionCounts();
    final all = const AttentionCounts(
      servis: 3,
      poPending: 5,
      invoice: 7,
      stokKritis: 2,
      produksiMenungguQc: 4,
    );

    test('semua 0 → tidak ada item perhatian', () {
      expect(attentionItemsFor('Owner', none), isEmpty);
      expect(attentionItemsFor('Mandor Titik', none), isEmpty);
      expect(attentionItemsFor('Kontraktor', none), isEmpty);
    });

    test('Owner: servis, PO, invoice, stok — dengan drill-down nyata', () {
      final items = attentionItemsFor('Owner', all);
      expect(items.map((i) => i.id), ['servis', 'po_pending', 'invoice',
          'stok_kritis']);

      final byId = {for (final i in items) i.id: i};
      expect(byId['servis']!.route, '/armada/servis');
      expect(byId['po_pending']!.route, '/dashboard/keuangan/po-pending');
      expect(byId['invoice']!.route, '/dashboard/keuangan/invoice');
      expect(byId['stok_kritis']!.route, '/inventory/stok?rendah=1');

      // Owner TIDAK ditampilkan antrian QC Mandor.
      expect(byId.containsKey('produksi_qc'), isFalse);
    });

    test('Admin Keuangan: tanpa stok kritis (inventory milik Owner)', () {
      final items = attentionItemsFor('Admin Keuangan', all);
      expect(items.map((i) => i.id), ['servis', 'po_pending', 'invoice']);
    });

    test('Mandor Titik hanya produksi menunggu QC → /qc', () {
      final items = attentionItemsFor('Mandor Titik', all);
      expect(items.map((i) => i.id), ['produksi_qc']);
      expect(items.single.route, '/qc');
      expect(items.single.subtitle, contains('4'));
    });

    test('Kontraktor tidak pernah dapat item', () {
      expect(attentionItemsFor('Kontraktor', all), isEmpty);
    });

    test('item dengan count 0 tidak dimunculkan (per item)', () {
      final counts = const AttentionCounts(servis: 0, poPending: 2);
      final items = attentionItemsFor('Owner', counts);
      expect(items.map((i) => i.id), ['po_pending']);

      expect(attentionItemsFor('Owner', const AttentionCounts(stokKritis: 0)),
          isEmpty);

      final mandorNone = attentionItemsFor(
        'Mandor Titik',
        const AttentionCounts(produksiMenungguQc: 0),
      );
      expect(mandorNone, isEmpty);
    });

    test('subtitle memuat jumlah nyata (bukan estimasi)', () {
      final items = attentionItemsFor('Owner', all);
      final byId = {for (final i in items) i.id: i};
      expect(byId['servis']!.subtitle, contains('3'));
      expect(byId['po_pending']!.subtitle, contains('5'));
      expect(byId['invoice']!.subtitle, contains('7'));
    });
  });

  group('AttentionItem dasar', () {
    test('membawa icon material & tone', () {
      const item = AttentionItem(
        id: 'x',
        label: 'X',
        subtitle: 's',
        icon: Icons.info,
        route: '/x',
        tone: AttentionTone.warning,
      );
      expect(item.label, 'X');
      expect(item.tone, AttentionTone.warning);
    });
  });
}