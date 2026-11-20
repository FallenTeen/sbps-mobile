import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/app_preferences.dart';
import 'package:sbps_mobile/core/app_router.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';
import 'package:sbps_mobile/features/auth/auth_providers.dart';
import 'package:sbps_mobile/features/auth/models/user.dart';
import 'package:sbps_mobile/features/dashboard/dashboard_home_screen.dart';
import 'package:sbps_mobile/features/dashboard/dashboard_providers.dart';
import 'package:sbps_mobile/features/dashboard/dashboard_repository.dart';
import 'package:sbps_mobile/features/dashboard/models.dart';
import 'package:sbps_mobile/features/inventory/inventory_models.dart';
import 'package:sbps_mobile/features/inventory/inventory_providers.dart';
import 'package:sbps_mobile/features/logistik/logistik_home_screen.dart';
import 'package:sbps_mobile/features/logistik/logistik_repository.dart';
import 'package:sbps_mobile/features/notifikasi/models/notification.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_providers.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_repository.dart';
import 'package:sbps_mobile/features/portal/portal_providers.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/features/proyek/pending_summary_provider.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/widgets/section_header.dart';
import 'package:sbps_mobile/shared/widgets/section_link.dart';

const _sectionLinks = <({String title, String label, String route})>[
  (
    title: 'Ringkasan Finansial',
    label: 'Lihat Keuangan',
    route: '/dashboard/keuangan',
  ),
];

enum _DataState { loading, error, empty, data }

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('section_links_test');
    Hive.init(hiveDir.path);
    await initializeDateFormatting('id_ID');
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  group('sectionHeaderWithLink', () {
    test('every table route is already declared by the app', () {
      for (final link in _sectionLinks) {
        expect(
          kAppRoutePaths,
          contains(link.route),
          reason: '${link.title} must use an existing route',
        );
      }
    });

    for (final link in _sectionLinks) {
      testWidgets('${link.title} has exactly one ${link.label} action', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: sectionHeaderWithLink(
                title: link.title,
                actionLabel: link.label,
                onAction: () => taps++,
              ),
            ),
          ),
        );

        final button = find.byType(TextButton);
        expect(button, findsOneWidget);
        expect(find.text(link.title), findsOneWidget);
        expect(
          find.descendant(of: button, matching: find.text(link.label)),
          findsOneWidget,
        );

        await tester.tap(button);
        await tester.pump();
        expect(taps, 1);
      });
    }

    testWidgets('plain SectionHeader has no action button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionHeader(title: 'Tanpa Aksi')),
        ),
      );

      expect(find.text('Tanpa Aksi'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('sections without an accessible destination', () {
    for (final state in _DataState.values) {
      testWidgets('dashboard activity keeps its single existing link in $state state', (
        tester,
      ) async {
        await pumpDashboard(tester, state);

        expect(find.text('Lihat Keuangan'), findsOneWidget);
        expect(find.text('Lihat Notifikasi'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('logistik antrean has no unauthorized ritase link in $state state', (
        tester,
      ) async {
        await pumpLogistik(tester, state);

        expect(find.text('Antrean Ritase'), findsOneWidget);
        expect(find.text('Lihat Ritase'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Future<void> pumpDashboard(WidgetTester tester, _DataState state) async {
  tester.view.physicalSize = const Size(390, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    final box = await Hive.openBox<String>('app_preferences');
    await box.delete('archived_notification_ids');
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(Dio()),
        authControllerProvider.overrideWith(() => _FakeAuth()),
        activeRoleProvider.overrideWith(() => _FakeRole('Owner')),
        selectedPortalProvider.overrideWith(() => _FakePortal()),
        unreadCountProvider.overrideWith(() => _FakeUnread()),
        pendingCountProvider.overrideWith(() => _FakePendingCount()),
        themeModeProvider.overrideWith(() => _FakeTheme()),
        pendingSummaryProvider.overrideWith((ref) => _FakePendingSummary()),
        dashboardRepositoryProvider.overrideWithValue(
          _FakeDashboardRepository(),
        ),
        inventorySummaryProvider.overrideWith(
          (ref) => Future.value(
            const InventorySummary(
              totalItem: 0,
              nilaiStok: 0,
              stokRendahCount: 0,
              requestPendingCount: 0,
            ),
          ),
        ),
        notifikasiRepositoryProvider.overrideWithValue(
          _FakeNotifikasiRepository(state),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const DashboardHomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Future<void> pumpLogistik(WidgetTester tester, _DataState state) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.runAsync(() async {
    await Hive.openBox<String>('app_preferences');
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(Dio()),
        authControllerProvider.overrideWith(() => _FakeAuth()),
        activeRoleProvider.overrideWith(() => _FakeRole('Logistik')),
        selectedPortalProvider.overrideWith(() => _FakePortal()),
        unreadCountProvider.overrideWith(() => _FakeUnread()),
        pendingCountProvider.overrideWith(() => _FakePendingCount()),
        themeModeProvider.overrideWith(() => _FakeTheme()),
        pendingSummaryProvider.overrideWith((ref) => _FakePendingSummary()),
        antreanVerifikasiRitaseProvider.overrideWith(
          (ref) => _antreanFuture(state),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const LogistikHomeScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Future<List<RitaseItem>> _antreanFuture(_DataState state) {
  switch (state) {
    case _DataState.loading:
      return Completer<List<RitaseItem>>().future;
    case _DataState.error:
      return Future.error(ApiException('Gagal memuat antrean.'));
    case _DataState.empty:
      return Future.value(const <RitaseItem>[]);
    case _DataState.data:
      return Future.value(const [
        RitaseItem(id: 'rit-1', tanggal: '2026-11-20', armadaPlat: 'B 1234 ABC'),
      ]);
  }
}

class _FakeNotifikasiRepository extends NotifikasiRepository {
  _FakeNotifikasiRepository(this.state) : super(api: ApiClient(dio: Dio()));

  final _DataState state;

  @override
  Future<NotificationsPage> getNotifications() async {
    switch (state) {
      case _DataState.loading:
        return Completer<NotificationsPage>().future;
      case _DataState.error:
        throw ApiException('Gagal memuat notifikasi.');
      case _DataState.empty:
        return const NotificationsPage(items: [], unreadCount: 0);
      case _DataState.data:
        return const NotificationsPage(
          items: [
            AppNotification(id: 'notif-1', title: 'Aktivitas baru', isRead: true),
          ],
          unreadCount: 0,
        );
    }
  }
}

class _FakeAuth extends AuthController {
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
  @override
  Future<AppPortal?> build() async => null;
}

class _FakeUnread extends UnreadCountNotifier {
  @override
  int build() => 0;

  @override
  Future<void> reload() async {}
}

class _FakePendingCount extends PendingCountNotifier {
  @override
  int build() => 0;

  @override
  Future<void> reload() async {}
}

class _FakeTheme extends ThemeModeNotifier {
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
  _FakeDashboardRepository() : super(api: ApiClient(dio: Dio()));

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
