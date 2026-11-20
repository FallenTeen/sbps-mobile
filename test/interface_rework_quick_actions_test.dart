import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sbps_mobile/core/app_preferences.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/features/auth/auth_providers.dart';
import 'package:sbps_mobile/features/auth/models/user.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_providers.dart';
import 'package:sbps_mobile/features/portal/portal_providers.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/features/proyek/home_quick_actions.dart';
import 'package:sbps_mobile/features/proyek/pending_summary_provider.dart';
import 'package:sbps_mobile/features/proyek/proyek_home_screen.dart';
import 'package:sbps_mobile/features/proyek/role_permissions.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/theme/breakpoints.dart';
import 'package:sbps_mobile/shared/theme/touch_targets.dart';
import 'package:sbps_mobile/shared/utils/module_routes.dart';

const _ownerLabels = [
  'Dashboard Finansial',
  'Dashboard Operasional',
  'Armada',
];

Future<void> pumpHomeAtSize(WidgetTester tester, String role, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => _FakeAuth()),
        activeRoleProvider.overrideWith(() => _FakeRole(role)),
        selectedPortalProvider.overrideWith(() => _FakePortal()),
        unreadCountProvider.overrideWith(() => _FakeUnread()),
        pendingCountProvider.overrideWith(() => _FakePresensiCount()),
        themeModeProvider.overrideWith(() => _FakeTheme()),
        pendingSummaryProvider.overrideWith((ref) => _FakePendingSummary()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProyekHomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Finder quickActionsSection() => find.ancestor(
  of: find.text('Aksi Cepat'),
  matching: find.byType(Column),
).first;

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('quick_actions_test');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  test('Owner quick actions use the agreed keys and order', () {
    expect(
      homeQuickActionKeysForRole('Owner'),
      ['keuangan', 'dashboard', 'armada'],
    );
  });

  test('Admin Keuangan quick actions use the agreed keys and order', () {
    expect(
      homeQuickActionKeysForRole('Admin Keuangan'),
      ['keuangan', 'dashboard', 'tracking'],
    );
  });

  test('Kontraktor quick actions use the agreed keys and order', () {
    expect(homeQuickActionKeysForRole('Kontraktor'), [
      'kontraktor',
      'dashboard',
    ]);
  });

  test('Mandor Proyek quick actions use the agreed keys and order', () {
    expect(homeQuickActionKeysForRole('Mandor Proyek'), ['produksi', 'qc']);
  });

  test('Driver Armada has no quick actions', () {
    expect(homeQuickActionKeysForRole('Driver Armada'), isEmpty);
  });

  test('every returned key is permitted and routable', () {
    for (final key in homeQuickActionKeysForRole('Admin Keuangan')) {
      expect(RolePermissions.canAccess('Admin Keuangan', key), isTrue);
      expect(moduleRouteFor(key), isNotNull);
    }
  });

  test('returns at most three keys', () {
    for (final role in const [
      'Owner',
      'Admin Keuangan',
      'Kontraktor',
      'Mandor Proyek',
      'Driver Armada',
    ]) {
      expect(homeQuickActionKeysForRole(role).length, lessThanOrEqualTo(3));
    }
  });

  testWidgets('renders mapped module labels for Owner at 390x844', (tester) async {
    await pumpHomeAtSize(tester, 'Owner', const Size(390, 844));

    expect(find.text('Aksi Cepat'), findsOneWidget);
    for (final label in _ownerLabels) {
      expect(
        find.descendant(
          of: quickActionsSection(),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders mapped module labels for Owner at 820x1180', (
    tester,
  ) async {
    await pumpHomeAtSize(tester, 'Owner', const Size(820, 1180));

    expect(find.text('Aksi Cepat'), findsOneWidget);
    for (final label in _ownerLabels) {
      expect(
        find.descendant(
          of: quickActionsSection(),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders mapped module labels for Owner at 1180x820', (
    tester,
  ) async {
    await pumpHomeAtSize(tester, 'Owner', const Size(1180, 820));

    expect(find.text('Aksi Cepat'), findsOneWidget);
    for (final label in _ownerLabels) {
      expect(
        find.descendant(
          of: quickActionsSection(),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick action targets meet touch minimums at 390x844', (
    tester,
  ) async {
    await pumpHomeAtSize(tester, 'Owner', const Size(390, 844));

    for (final label in _ownerLabels) {
      final labelFinder = find.descendant(
        of: quickActionsSection(),
        matching: find.text(label),
      );
      await tester.ensureVisible(labelFinder);
      final button = find.ancestor(
        of: labelFinder,
        matching: find.byType(InkWell),
      ).first;
      expect(tester.getSize(button).height, greaterThanOrEqualTo(TouchTargets.minTap));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick action targets meet comfortable minimums on tablets', (
    tester,
  ) async {
    for (final size in const [Size(820, 1180), Size(1180, 820)]) {
      await pumpHomeAtSize(tester, 'Owner', size);

      for (final label in _ownerLabels) {
        final labelFinder = find.descendant(
          of: quickActionsSection(),
          matching: find.text(label),
        );
        await tester.ensureVisible(labelFinder);
        final button = find.ancestor(
          of: labelFinder,
          matching: find.byType(InkWell),
        ).first;
        expect(
          tester.getSize(button).height,
          greaterThanOrEqualTo(TouchTargets.comfortable),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('quick actions stay inside the readable content width', (
    tester,
  ) async {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1180, 820),
    ]) {
      await pumpHomeAtSize(tester, 'Owner', size);

      final sectionWidth = tester.getSize(quickActionsSection()).width;
      final expectedWidth = size.width < AppBreakpoints.maxContentWidth
          ? size.width - 32
          : AppBreakpoints.maxContentWidth - 32;
      expect(sectionWidth, expectedWidth);
      expect(sectionWidth, lessThanOrEqualTo(AppBreakpoints.maxContentWidth));
      expect(sectionWidth, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Mandor Proyek sees only its two permitted actions', (
    tester,
  ) async {
    await pumpHomeAtSize(tester, 'Mandor Proyek', const Size(390, 844));

    expect(
      find.descendant(
        of: quickActionsSection(),
        matching: find.text('Produksi'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: quickActionsSection(),
        matching: find.text('Quality Control'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: quickActionsSection(),
        matching: find.text('Dashboard Finansial'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Driver Armada has no Aksi Cepat section', (tester) async {
    await pumpHomeAtSize(tester, 'Driver Armada', const Size(390, 844));

    expect(find.text('Aksi Cepat'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAuth extends AuthController {
  _FakeAuth();

  @override
  Future<User?> build() async => null;
}

class _FakeRole extends ActiveRoleNotifier {
  _FakeRole(this.role);

  final String role;

  @override
  String? build() => role;
}

class _FakePortal extends SelectedPortalNotifier {
  _FakePortal();

  @override
  Future<AppPortal?> build() async => null;
}

class _FakeUnread extends UnreadCountNotifier {
  _FakeUnread();

  @override
  int build() => 0;

  @override
  Future<void> reload() async {}
}

class _FakePresensiCount extends PendingCountNotifier {
  _FakePresensiCount();

  @override
  int build() => 0;

  @override
  Future<void> reload() async {}
}

class _FakeTheme extends ThemeModeNotifier {
  _FakeTheme();

  @override
  Future<ThemeMode> build() async => ThemeMode.light;
}

class _FakePendingSummary extends PendingSummary {
  _FakePendingSummary() : super(repository: OutboxRepository());

  @override
  Future<ModulePendingCounts> getSummary(String role) async =>
      const ModulePendingCounts();
}
