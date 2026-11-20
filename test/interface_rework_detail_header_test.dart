import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/features/armada/armada_providers.dart';
import 'package:sbps_mobile/features/armada/armada_repository.dart';
import 'package:sbps_mobile/features/armada/detail_ritase_screen.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';
import 'package:sbps_mobile/features/armada/riwayat_ritase_screen.dart';
import 'package:sbps_mobile/features/auth/auth_providers.dart';
import 'package:sbps_mobile/features/notifikasi/models/notification.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_providers.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_repository.dart';
import 'package:sbps_mobile/features/notifikasi/notifikasi_screen.dart';
import 'package:sbps_mobile/features/version/version_gate.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/widgets/app_screen_frame.dart';
import 'package:sbps_mobile/shared/widgets/brand_strip.dart';
import 'package:sbps_mobile/shared/widgets/portal_switch_button.dart';

const List<Size> _viewSizes = [
  Size(390, 844),
  Size(820, 1180),
  Size(1180, 820),
];

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _ConstantGate extends VersionGateController {
  @override
  Future<VersionGateState> build() async => VersionGateState.ok;
}

class _FakeArmadaRepository extends ArmadaRepository {
  _FakeArmadaRepository({this.bisaSelesaikan = false})
    : super(
        api: ApiClient(dio: Dio()),
        outbox: OutboxRepository(),
        sync: OutboxSyncService(
          OutboxRepository(),
          ApiClient(dio: Dio()),
          connectivityStream: () => const Stream.empty(),
        ),
      );

  final bool bisaSelesaikan;

  @override
  Future<List<ArmadaSaya>> getArmadaSaya() async => const [];

  @override
  Future<RitasePage> getRitase({
    int page = 1,
    int perPage = 15,
    String? tanggal,
  }) async =>
      const RitasePage(items: [], currentPage: 1, lastPage: 1, total: 0);

  @override
  Future<RitaseItem> getRitaseDetail(String id) async => RitaseItem(
    id: id,
    tanggal: '2026-11-20',
    material: 'Pasir',
    jumlahRit: 1,
    status: 'disetujui',
    bisaSelesaikan: bisaSelesaikan,
  );
}

class _FakeNotifikasiRepository extends NotifikasiRepository {
  _FakeNotifikasiRepository() : super(api: ApiClient(dio: Dio()));

  @override
  Future<NotificationsPage> getNotifications() async =>
      const NotificationsPage(items: [], unreadCount: 0);
}

class _FakeRole extends ActiveRoleNotifier {
  @override
  String? build() => 'Owner';
}

Widget _armadaApp(Widget screen, {bool bisaSelesaikan = false}) =>
    ProviderScope(
      overrides: [
        armadaRepositoryProvider.overrideWithValue(
          _FakeArmadaRepository(bisaSelesaikan: bisaSelesaikan),
        ),
        versionGateProvider.overrideWith(() => _ConstantGate()),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
    );

Widget _notifikasiApp() => ProviderScope(
  overrides: [
    notifikasiRepositoryProvider.overrideWithValue(_FakeNotifikasiRepository()),
    versionGateProvider.overrideWith(() => _ConstantGate()),
    activeRoleProvider.overrideWith(() => _FakeRole()),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: const NotifikasiScreen(),
  ),
);

void _expectUniformHeader(WidgetTester tester, Size size, String title) {
  expect(find.byWidgetPredicate((w) => w is BrandStrip), findsOneWidget);
  expect(
    find.descendant(of: find.byType(AppBar), matching: find.text(title)),
    findsOneWidget,
  );
  expect(tester.getSize(find.byType(AppScreenFrame)).width, size.width);
}

void _expectInViewport(WidgetTester tester, Finder finder, Size size) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width + 1));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height + 1));
  expect(rect.width, greaterThan(0));
}

void main() {
  testWidgets('RiwayatRitaseScreen uses uniform header', (tester) async {
    await tester.pumpWidget(_armadaApp(const RiwayatRitaseScreen()));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is BrandStrip), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is PortalSwitchButton),
      findsOneWidget,
    );
  });

  testWidgets('DetailRitaseScreen uses uniform header', (tester) async {
    await tester.pumpWidget(_armadaApp(const DetailRitaseScreen(id: '1')));
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is BrandStrip), findsOneWidget);
    expect(find.text('Armada / Detail Muatan'), findsOneWidget);
  });

  testWidgets('NotifikasiScreen uses uniform header and keeps actions', (
    tester,
  ) async {
    await tester.pumpWidget(_notifikasiApp());
    await tester.pumpAndSettle();

    expect(find.byWidgetPredicate((w) => w is BrandStrip), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is PortalSwitchButton),
      findsOneWidget,
    );
    expect(find.byTooltip('Segarkan'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
  });

  for (final size in _viewSizes) {
    testWidgets('riwayat ritase header fits ${size.width}x${size.height}', (
      tester,
    ) async {
      _setView(tester, size);
      await tester.pumpWidget(_armadaApp(const RiwayatRitaseScreen()));
      await tester.pumpAndSettle();

      _expectUniformHeader(tester, size, 'Riwayat Muatan');
      _expectInViewport(
        tester,
        find.byWidgetPredicate((w) => w is PortalSwitchButton),
        size,
      );
      _expectInViewport(tester, find.byType(SegmentedButton<int>), size);
      _expectInViewport(tester, find.text('Input Muatan Baru'), size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail ritase header fits ${size.width}x${size.height}', (
      tester,
    ) async {
      _setView(tester, size);
      await tester.pumpWidget(
        _armadaApp(const DetailRitaseScreen(id: '1'), bisaSelesaikan: true),
      );
      await tester.pumpAndSettle();

      _expectUniformHeader(tester, size, 'Detail Muatan');
      expect(find.text('Armada / Detail Muatan'), findsOneWidget);
      _expectInViewport(
        tester,
        find.byWidgetPredicate((w) => w is PortalSwitchButton),
        size,
      );
      _expectInViewport(tester, find.text('Selesaikan Ritase'), size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('notifikasi header fits ${size.width}x${size.height}', (
      tester,
    ) async {
      _setView(tester, size);
      await tester.pumpWidget(_notifikasiApp());
      await tester.pumpAndSettle();

      _expectUniformHeader(tester, size, 'Notifikasi');
      _expectInViewport(
        tester,
        find.byWidgetPredicate((w) => w is PortalSwitchButton),
        size,
      );
      _expectInViewport(tester, find.byTooltip('Segarkan'), size);
      _expectInViewport(tester, find.byTooltip('Menu'), size);
      _expectInViewport(tester, find.text('Belum Ada Notifikasi'), size);
      expect(tester.takeException(), isNull);
    });
  }
}
