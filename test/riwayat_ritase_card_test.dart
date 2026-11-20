import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/features/armada/armada_providers.dart';
import 'package:sbps_mobile/features/armada/armada_repository.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';
import 'package:sbps_mobile/features/armada/riwayat_ritase_screen.dart';
import 'package:sbps_mobile/features/version/version_gate.dart';
import 'package:sbps_mobile/shared/theme/app_spacing.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/theme/breakpoints.dart';

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

RitaseItem _ritaseLengkap({
  required bool selesai,
  required bool bisaSelesaikan,
}) => RitaseItem(
  id: 'ritase-42',
  tanggal: '2026-11-20',
  material: 'Pasir',
  jumlahRit: 2,
  status: 'disetujui',
  ruteAsal: 'Tambang',
  ruteTujuan: 'Plant',
  jumlahDriver: 12,
  jumlahVerifikasiLogistik: 12,
  satuanMuatan: 'ton',
  totalUpahRit: 250000,
  statusVerifikasiLogistik: 'terverifikasi',
  statusVerifikasiSecurity: 'terverifikasi',
  wajibJembatanTimbang: true,
  selesai: selesai,
  bisaSelesaikan: bisaSelesaikan,
);

Widget _card(RitaseItem ritase, {required VoidCallback onTap}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: SingleChildScrollView(
      child: RitaseListCard(ritase: ritase, onTap: onTap),
    ),
  ),
);

class _ConstantGate extends VersionGateController {
  @override
  Future<VersionGateState> build() async => VersionGateState.ok;
}

class _FakeScreenRepository extends ArmadaRepository {
  _FakeScreenRepository()
    : super(
        api: ApiClient(dio: Dio()),
        outbox: OutboxRepository(),
        sync: OutboxSyncService(
          OutboxRepository(),
          ApiClient(dio: Dio()),
          connectivityStream: () => const Stream.empty(),
        ),
      );

  @override
  Future<List<ArmadaSaya>> getArmadaSaya() async => const [];

  @override
  Future<RitasePage> getRitase({
    int page = 1,
    int perPage = 15,
    String? tanggal,
  }) async =>
      const RitasePage(items: [], currentPage: 1, lastPage: 1, total: 0);
}

Widget _riwayatApp() => ProviderScope(
  overrides: [
    armadaRepositoryProvider.overrideWithValue(_FakeScreenRepository()),
    versionGateProvider.overrideWith(() => _ConstantGate()),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: const RiwayatRitaseScreen(),
  ),
);

Finder _boundedContent() => find.ancestor(
  of: find.byType(SegmentedButton<int>),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is ConstrainedBox &&
        widget.constraints.maxWidth ==
            AppBreakpoints.maxContentWidth - (AppSpacing.md * 2),
  ),
);

void main() {
  testWidgets('kartu ritase memanggil onTap dan memakai path detail', (
    tester,
  ) async {
    final ritase = RitaseItem(
      id: 'ritase-42',
      tanggal: '2026-11-20',
      material: 'Pasir',
      jumlahRit: 2,
      status: 'draft',
    );
    var tapped = false;

    await tester.pumpWidget(_card(ritase, onTap: () => tapped = true));
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tapped, isTrue);
    expect(ritaseDetailPath(ritase), '/armada/ritase/ritase-42');
  });

  testWidgets('kartu ritase tidak menampilkan aksi selesaikan', (tester) async {
    final ritase = RitaseItem(
      id: 'ritase-43',
      tanggal: '2026-11-20',
      status: 'draft',
      bisaSelesaikan: true,
    );
    var detailTapped = false;

    await tester.pumpWidget(_card(ritase, onTap: () => detailTapped = true));

    expect(find.text('Selesaikan Ritase'), findsNothing);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(detailTapped, isTrue);
  });

  testWidgets(
    'kartu memakai badge bersama untuk status, verifikasi, dan selesai',
    (tester) async {
      final ritase = _ritaseLengkap(selesai: true, bisaSelesaikan: false);

      await tester.pumpWidget(_card(ritase, onTap: () {}));

      expect(find.text('Disetujui'), findsOneWidget);
      expect(find.text('Terverifikasi'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Selesaikan Ritase'), findsNothing);
    },
  );

  testWidgets('kartu ritase dengan nilai panjang tidak overflow di 390x844', (
    tester,
  ) async {
    _setView(tester, const Size(390, 844));
    final ritase = RitaseItem(
      id: 'ritase-panjang',
      tanggal: '2026-11-20',
      material: 'Pasir',
      jumlahRit: 2,
      status: 'disetujui',
      jumlahDriver: 9223372036854775807.0,
      jumlahVerifikasiLogistik: 9007199254740991.0,
      satuanMuatan: 'ton kering sangat panjang untuk menguji batas lebar kartu',
    );

    await tester.pumpWidget(_card(ritase, onTap: () {}));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rect = tester.getRect(find.byType(RitaseListCard));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390 + 1));
  });

  for (final size in _viewSizes) {
    testWidgets(
      'riwayat ritase membatasi lebar konten di ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        _setView(tester, size);

        await tester.pumpWidget(_riwayatApp());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final content = _boundedContent();
        expect(content, findsOneWidget);
        final rect = tester.getRect(content);
        final available = size.width - (AppSpacing.md * 2);
        final expectedWidth =
            available < AppBreakpoints.maxContentWidth - (AppSpacing.md * 2)
            ? available
            : AppBreakpoints.maxContentWidth - (AppSpacing.md * 2);
        expect(rect.width, closeTo(expectedWidth, 1));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width + 1));
      },
    );

    testWidgets(
      'kartu ritase muat di ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        _setView(tester, size);
        final ritase = _ritaseLengkap(selesai: true, bisaSelesaikan: true);

        await tester.pumpWidget(_card(ritase, onTap: () {}));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Selesaikan Ritase'), findsNothing);
        final rect = tester.getRect(find.byType(RitaseListCard));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width + 1));
        expect(find.text('Selesai'), findsOneWidget);
      },
    );
  }
}
