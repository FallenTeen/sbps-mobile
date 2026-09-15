import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/dashboard/models.dart';
import 'package:sbps_mobile/features/dashboard/widgets/charts.dart';
import 'package:sbps_mobile/shared/widgets/adaptive_master_detail.dart';
import 'package:sbps_mobile/shared/widgets/adaptive_nav_shell.dart';
import 'package:sbps_mobile/shared/widgets/searchable_list_header.dart';

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _destinations = [
  AdaptiveNavDestination(
    key: 'produksi',
    label: 'Produksi',
    icon: Icons.factory_outlined,
    selectedIcon: Icons.factory,
  ),
  AdaptiveNavDestination(
    key: 'qc',
    label: 'QC',
    icon: Icons.science_outlined,
    selectedIcon: Icons.science,
  ),
  AdaptiveNavDestination(
    key: 'armada',
    label: 'Armada',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
  AdaptiveNavDestination(
    key: 'dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
];

final _produksiItems = [
  const ProduksiChartPoint(
    minggu: '2025-01-06',
    totalOutput: 120,
    jumlahSesi: 5,
  ),
  const ProduksiChartPoint(
    minggu: '2025-01-13',
    totalOutput: 95,
    jumlahSesi: 4,
  ),
  const ProduksiChartPoint(
    minggu: '2025-01-20',
    totalOutput: 150,
    jumlahSesi: 6,
  ),
  const ProduksiChartPoint(
    minggu: '2025-01-27',
    totalOutput: 80,
    jumlahSesi: 3,
  ),
];

final _keuanganItems = [
  const KeuanganChartPoint(
    minggu: '2025-01-06',
    masuk: 50000000,
    keluar: 30000000,
  ),
  const KeuanganChartPoint(
    minggu: '2025-01-13',
    masuk: 40000000,
    keluar: 45000000,
  ),
  const KeuanganChartPoint(
    minggu: '2025-01-20',
    masuk: 70000000,
    keluar: 25000000,
  ),
  const KeuanganChartPoint(
    minggu: '2025-01-27',
    masuk: 35000000,
    keluar: 20000000,
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Pump widget inside [MaterialApp] at a given logical size + text scale.
Future<void> _pumpAtSize(
  WidgetTester tester, {
  required Widget child,
  required double width,
  double height = 800,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ========================================================================
  // 8.5 — Font scaling 130%
  // ========================================================================

  group('AdaptiveNavShell — no overflow at 130% font scale', () {
    testWidgets('compact: NavigationBar', (tester) async {
      await _pumpAtSize(
        tester,
        width: 400,
        textScale: 1.3,
        child: AdaptiveNavShell(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Center(child: Text('Content')),
        ),
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('medium: NavigationRail', (tester) async {
      await _pumpAtSize(
        tester,
        width: 700,
        textScale: 1.3,
        child: AdaptiveNavShell(
          currentIndex: 1,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Center(child: Text('Content')),
        ),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded: NavigationRail extended', (tester) async {
      await _pumpAtSize(
        tester,
        width: 1000,
        textScale: 1.3,
        child: AdaptiveNavShell(
          currentIndex: 2,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Center(child: Text('Content')),
        ),
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('AdaptiveMasterDetail — no overflow at 130% font scale', () {
    testWidgets('expanded layout with SearchableListHeader + list tiles', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        width: 1000,
        textScale: 1.3,
        child: AdaptiveMasterDetail(
          pushRouteFor: (id) => '/detail/$id',
          masterBuilder: (context, selectedId, onSelect) => Column(
            children: [
              SearchableListHeader(
                hintText: 'Cari item panjang judulnya untuk cek overflow...',
                onChanged: (_) {},
                child: const Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text('Filter A'),
                      selected: false,
                      onSelected: null,
                    ),
                    FilterChip(
                      label: Text('Filter B'),
                      selected: true,
                      onSelected: null,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: 5,
                  itemBuilder: (context, i) {
                    return Card(
                      child: ListTile(
                        selected: selectedId == '$i',
                        title: Text(
                          'Item $i: judul yang sengaja dibuat cukup panjang '
                          'supaya diukur overflow pada skala font 130%',
                        ),
                        subtitle: const Text(
                          'Subtitle dengan teks panjang juga untuk memastikan '
                          'layout wrapping bekerja dengan benar di 130%',
                        ),
                        onTap: () => onSelect('$i'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          detailBuilder: (context, id) => Center(child: Text('Detail $id')),
          emptyDetailPlaceholder: const Center(
            child: Text('Pilih item untuk melihat detail'),
          ),
        ),
      );

      // Select an item — detail panel should appear (expanded mode)
      final item0 = find.textContaining('Item 0: judul yang sengaja');
      await tester.tap(item0);
      await tester.pump();
      expect(find.text('Detail 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Chart — no overflow at 130% font scale', () {
    testWidgets('ProduksiBarChart', (tester) async {
      await _pumpAtSize(
        tester,
        width: 400,
        textScale: 1.3,
        child: ProduksiBarChart(items: _produksiItems),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('KeuanganBarChart', (tester) async {
      await _pumpAtSize(
        tester,
        width: 400,
        textScale: 1.3,
        child: KeuanganBarChart(items: _keuanganItems),
      );
      expect(tester.takeException(), isNull);
    });
  });

  // ========================================================================
  // 8.5 — TalkBack / Semantics
  // ========================================================================

  group('AdaptiveNavShell — TalkBack semantics labels', () {
    testWidgets('NavigationBar (compact) exposes all destination labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpAtSize(
        tester,
        width: 400,
        child: AdaptiveNavShell(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Center(child: Text('Content')),
        ),
      );

      for (final d in _destinations) {
        expect(
          find.bySemanticsLabel(RegExp(d.label)),
          findsWidgets,
          reason: 'Semantics for "${d.label}" should be readable by TalkBack',
        );
      }
      handle.dispose();
    });

    testWidgets('NavigationRail (expanded) exposes all destination labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpAtSize(
        tester,
        width: 1000,
        child: AdaptiveNavShell(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Center(child: Text('Content')),
        ),
      );

      for (final d in _destinations) {
        expect(
          find.bySemanticsLabel(RegExp(d.label)),
          findsWidgets,
          reason: 'Rail label "${d.label}" should be readable by TalkBack',
        );
      }
      handle.dispose();
    });
  });

  group('Chart — Semantics summary for TalkBack', () {
    testWidgets('ProduksiBarChart semantic label contains weekly summary', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        width: 400,
        child: ProduksiBarChart(items: _produksiItems),
      );

      // fmtMingguLabel('2025-01-06') → '6/1'; fmtNum(120) → '120'
      expect(
        find.bySemanticsLabel(RegExp('Produksi minggu 6/1.*120 unit')),
        findsWidgets,
        reason: 'TalkBack should read the production summary for week 6/1',
      );
    });

    testWidgets('KeuanganBarChart semantic label contains weekly summary', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        width: 400,
        child: KeuanganBarChart(items: _keuanganItems),
      );

      // Should contain "Minggu 6/1" + "masuk Rp"
      expect(
        find.bySemanticsLabel(RegExp('Minggu 6/1.*masuk.*Rp')),
        findsWidgets,
        reason: 'TalkBack should read the keuangan summary for week 6/1',
      );
    });
  });
}
