import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/app_preferences.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/features/auth/auth_providers.dart';
import 'package:sbps_mobile/features/auth/models/user.dart';
import 'package:sbps_mobile/features/dashboard/dashboard_home_screen.dart';
import 'package:sbps_mobile/features/dashboard/dashboard_providers.dart';
import 'package:sbps_mobile/features/dashboard/dashboard_repository.dart';
import 'package:sbps_mobile/features/dashboard/models.dart';
import 'package:sbps_mobile/features/notifikasi/models/notification.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_providers.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_repository.dart';
import 'package:sbps_mobile/features/portal/portal_providers.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/features/proyek/pending_summary_provider.dart';
import 'package:sbps_mobile/features/proyek/proyek_home_screen.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/theme/breakpoints.dart';
import 'package:sbps_mobile/shared/widgets/app_screen_frame.dart';
import 'package:sbps_mobile/shared/widgets/brand_strip.dart';

double expectedBodyWidth(Size size) =>
    size.width - 32 > AppBreakpoints.maxContentWidth - 32
    ? AppBreakpoints.maxContentWidth - 32
    : size.width - 32;

Future<GoRouter> pumpHeaderScreen(
  WidgetTester tester, {
  required Widget screen,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    final box = await Hive.openBox<String>('app_preferences');
    await box.delete('pinned_modules');
  });

  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => screen,
        routes: [
          GoRoute(
            path: 'keuangan',
            builder: (_, __) => const _KeuanganStub(),
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(Dio()),
        authControllerProvider.overrideWith(() => _FakeAuth()),
        activeRoleProvider.overrideWith(() => _FakeRole('Owner')),
        selectedPortalProvider.overrideWith(() => _FakePortal()),
        unreadCountProvider.overrideWith(() => _FakeUnread()),
        pendingCountProvider.overrideWith(() => _FakePresensiCount()),
        themeModeProvider.overrideWith(() => _FakeTheme()),
        pendingSummaryProvider.overrideWith((ref) => _FakePendingSummary()),
        dashboardRepositoryProvider.overrideWithValue(
          _FakeDashboardRepository(),
        ),
        notifikasiRepositoryProvider.overrideWithValue(
          _FakeNotifikasiRepository(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
  return router;
}

void expectHeaderBasics(WidgetTester tester, String title) {
  expect(
    find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    ),
    findsOneWidget,
  );
  expect(find.byWidgetPredicate((w) => w is BrandStrip), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(AppScreenFrame),
      matching: find.byType(TextField),
    ),
    findsOneWidget,
  );
  expect(find.text('Terakhir Dibuka'), findsNothing);
}

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('home_header_test');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Proyek home uses the uniform header for Owner', (tester) async {
    await pumpHeaderScreen(
      tester,
      screen: const ProyekHomeScreen(),
      size: const Size(390, 844),
    );

    expect(find.text('Beranda'), findsOneWidget);
    expectHeaderBasics(tester, 'Beranda');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard uses the uniform header for Owner', (tester) async {
    await pumpHeaderScreen(
      tester,
      screen: const DashboardHomeScreen(),
      size: const Size(390, 844),
    );

    expect(find.text('Dashboard Operasional'), findsWidgets);
    expectHeaderBasics(tester, 'Dashboard Operasional');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dashboard keeps the /dashboard/keuangan link', (tester) async {
    final router = await pumpHeaderScreen(
      tester,
      screen: const DashboardHomeScreen(),
      size: const Size(390, 2400),
    );

    final link = find.ancestor(
      of: find.text('Dashboard Finansial'),
      matching: find.byType(ListTile),
    );
    expect(link, findsOneWidget);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(router.state.uri.toString(), '/dashboard/keuangan');
    expect(find.byType(_KeuanganStub), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(390, 844),
    Size(820, 1180),
    Size(1180, 820),
  ]) {
    testWidgets('Proyek home header fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await pumpHeaderScreen(
        tester,
        screen: const ProyekHomeScreen(),
        size: size,
      );

      expectHeaderBasics(tester, 'Beranda');
      expect(
        tester.getSize(find.byType(AppScreenFrame)).width,
        size.width,
      );
      final body = find.descendant(
        of: find.byType(AppScreenFrame),
        matching: find.byType(ListView),
      ).first;
      expect(tester.getSize(body).width, expectedBodyWidth(size));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dashboard header fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await pumpHeaderScreen(
        tester,
        screen: const DashboardHomeScreen(),
        size: size,
      );

      expectHeaderBasics(tester, 'Dashboard Operasional');
      expect(
        tester.getSize(find.byType(AppScreenFrame)).width,
        size.width,
      );
      final body = find.descendant(
        of: find.byType(AppScreenFrame),
        matching: find.byType(ListView),
      ).first;
      expect(tester.getSize(body).width, expectedBodyWidth(size));
      expect(tester.takeException(), isNull);
    });
  }
}

class _KeuanganStub extends StatelessWidget {
  const _KeuanganStub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('KeuanganStub')));
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

class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository() : super(api: ApiClient());

  @override
  Future<DashboardOverview> getOverview() async =>
      const DashboardOverview(tanggal: '', totalTitik: 0, items: []);

  @override
  Future<ArmadaStatusData> getArmadaStatus() async =>
      const ArmadaStatusData(total: 0, items: []);

  @override
  Future<KehadiranDivisiData> getKehadiranDivisi() async =>
      const KehadiranDivisiData(tanggal: '', totalHadir: 0, items: []);

  @override
  Future<ProduksiChart> getProduksiChart({int? bulan, int? tahun}) async =>
      ProduksiChart(bulan: bulan ?? 1, tahun: tahun ?? 1, items: const []);

  @override
  Future<PoPendingPage> getPoPending() async =>
      const PoPendingPage(total: 0, items: []);

  @override
  Future<InvoicePendingPage> getInvoiceBelumDibayar() async =>
      const InvoicePendingPage(total: 0, items: []);
}

class _FakeNotifikasiRepository extends NotifikasiRepository {
  _FakeNotifikasiRepository() : super(api: ApiClient());

  @override
  Future<NotificationsPage> getNotifications() async =>
      const NotificationsPage(items: [], unreadCount: 0);
}
