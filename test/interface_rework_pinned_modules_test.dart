import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/widgets/module_shortcut.dart';
import 'package:sbps_mobile/shared/widgets/pinned_modules_row.dart';

Future<void> pumpPinnedRow(
  WidgetTester tester, {
  required Set<String> allowedModules,
  String? pinnedValue,
  Size? size,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  await tester.runAsync(() async {
    final box = await Hive.openBox<String>('app_preferences');
    await box.delete('pinned_modules');
    if (pinnedValue != null) {
      await box.put('pinned_modules', pinnedValue);
    }
  });

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PinnedModulesRow(allowedModules: allowedModules),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('pinned_modules_test');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  test('visiblePinnedModules keeps order and drops disallowed keys', () {
    expect(
      visiblePinnedModules(
        ['produksi', 'dashboard', 'logistik', 'armada'],
        const {'dashboard', 'armada'},
      ),
      ['dashboard', 'armada'],
    );
  });

  testWidgets('empty allowed modules hides the quick menu', (tester) async {
    await pumpPinnedRow(tester, allowedModules: const <String>{});

    expect(find.text('Akses Cepat'), findsNothing);
    expect(find.byType(ModuleShortcut), findsNothing);
  });

  testWidgets('shows only pinned modules the role may access', (tester) async {
    await pumpPinnedRow(
      tester,
      allowedModules: const {'dashboard'},
      pinnedValue: 'produksi,dashboard',
    );

    expect(find.text('Akses Cepat'), findsOneWidget);
    expect(find.byType(ModuleShortcut), findsOneWidget);
    expect(find.text('Dashboard Operasional'), findsOneWidget);
  });

  testWidgets('fits a normal phone at 390x844', (tester) async {
    await pumpPinnedRow(
      tester,
      allowedModules: const {'dashboard', 'produksi', 'armada', 'logistik'},
      size: const Size(390, 844),
    );

    expect(find.byType(ModuleShortcut), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits tablet portrait at 820x1180', (tester) async {
    await pumpPinnedRow(
      tester,
      allowedModules: const {'dashboard', 'produksi', 'armada', 'logistik'},
      size: const Size(820, 1180),
    );

    expect(find.byType(ModuleShortcut), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reorder with a hidden pinned key keeps hidden slots and persists a valid order',
    (tester) async {
      await pumpPinnedRow(
        tester,
        allowedModules: const {
          'tracking',
          'dashboard',
          'keuangan',
          'armada',
          'kontraktor',
        },
        pinnedValue: 'dashboard,produksi,armada,logistik',
      );

      expect(
        tester
            .widgetList<ModuleShortcut>(find.byType(ModuleShortcut))
            .map((w) => w.label)
            .toList(),
        ['Dashboard Operasional', 'Armada'],
      );

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      await tester.runAsync(() async {
        list.onReorder!(1, 0);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester
            .widgetList<ModuleShortcut>(find.byType(ModuleShortcut))
            .map((w) => w.label)
            .toList(),
        ['Armada', 'Dashboard Operasional'],
      );

      final saved = await tester.runAsync(() async {
        final box = await Hive.openBox<String>('app_preferences');
        return box.get('pinned_modules');
      });
      expect(saved, 'armada,produksi,dashboard,logistik');
    },
  );

  testWidgets('fits tablet landscape at 1180x820', (tester) async {
    await pumpPinnedRow(
      tester,
      allowedModules: const {'dashboard', 'produksi', 'armada', 'logistik'},
      size: const Size(1180, 820),
    );

    expect(find.byType(ModuleShortcut), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });
}
