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
import 'package:sbps_mobile/features/version/version_gate.dart';
import 'package:sbps_mobile/shared/theme/app_colors.dart';
import 'package:sbps_mobile/shared/theme/app_spacing.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/theme/breakpoints.dart';
import 'package:sbps_mobile/shared/widgets/ritase_status_badges.dart';
import 'package:sbps_mobile/shared/widgets/status_pill.dart';
import 'package:sbps_mobile/shared/widgets/sticky_action_bar.dart';
import 'package:sbps_mobile/shared/widgets/timeline.dart';

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

class _FakeRitaseRepository extends ArmadaRepository {
  _FakeRitaseRepository({
    required this.bisaSelesaikan,
    required this.selesai,
    this.selesaiError,
  }) : super(
         api: ApiClient(dio: Dio()),
         outbox: OutboxRepository(),
         sync: OutboxSyncService(
           OutboxRepository(),
           ApiClient(dio: Dio()),
           connectivityStream: () => const Stream.empty(),
         ),
       );

  bool bisaSelesaikan;
  bool selesai;
  final String? selesaiError;
  final List<String> detailIds = [];
  final List<String> selesaiIds = [];

  RitaseItem _item() => RitaseItem(
    id: 'ritase-1',
    tanggal: '2026-11-20',
    material: 'Pasir',
    jumlahRit: 2,
    status: 'disetujui',
    armadaPlat: 'B 1234 ABC',
    ruteAsal: 'Tambang',
    ruteTujuan: 'Plant',
    proyek: 'Proyek A',
    titik: 'Titik 1',
    catatan: 'Catatan lapangan',
    statusVerifikasiLogistik: 'terverifikasi',
    bisaSelesaikan: bisaSelesaikan,
    selesai: selesai,
  );

  @override
  Future<RitaseItem> getRitaseDetail(String id) async {
    detailIds.add(id);
    return _item();
  }

  @override
  Future<RitasePage> getRitase({
    int page = 1,
    int perPage = 15,
    String? tanggal,
  }) async =>
      const RitasePage(items: [], currentPage: 1, lastPage: 1, total: 0);

  @override
  Future<RitaseItem> selesaikanRitase(String id) async {
    selesaiIds.add(id);
    if (selesaiError != null) throw ApiException(selesaiError!);
    bisaSelesaikan = false;
    selesai = true;
    return _item();
  }
}

Widget _detailApp(_FakeRitaseRepository repo) => ProviderScope(
  overrides: [
    armadaRepositoryProvider.overrideWithValue(repo),
    versionGateProvider.overrideWith(() => _ConstantGate()),
  ],
  child: MaterialApp(
    theme: AppTheme.lightTheme,
    home: DetailRitaseScreen(id: 'ritase-1'),
  ),
);

Finder _boundedContent() => find.ancestor(
  of: find.byType(RefreshIndicator),
  matching: find.byWidgetPredicate(
    (widget) =>
        widget is ConstrainedBox &&
        widget.constraints.maxWidth ==
            AppBreakpoints.maxContentWidth - (AppSpacing.md * 2),
  ),
);

void main() {
  test('mapping state timeline ritase', () {
    expect(timelineStatusFor('done'), TimelineStatus.done);
    expect(timelineStatusFor('current'), TimelineStatus.current);
    expect(timelineStatusFor('pending'), TimelineStatus.pending);
    expect(timelineStatusFor('skipped'), TimelineStatus.pending);
    expect(timelineStatusFor('tidak-dikenal'), TimelineStatus.pending);
  });

  testWidgets('ritaseStatusBadges merender status, verifikasi, dan selesai', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Wrap(
            children: ritaseStatusBadges(
              statusLabel: 'Disetujui',
              terverifikasi: true,
              selesai: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.text('Terverifikasi'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is StatusPill), findsNWidgets(3));
  });

  testWidgets('ritaseStatusBadges tanpa verifikasi dan selesai', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Wrap(
            children: ritaseStatusBadges(
              statusLabel: 'Draft',
              terverifikasi: false,
              selesai: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Terverifikasi'), findsNothing);
    expect(find.text('Selesai'), findsNothing);
    expect(find.byWidgetPredicate((w) => w is StatusPill), findsOneWidget);
  });

  testWidgets('ritaseStatusBadges memakai warna tema ambient', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Wrap(
            children: ritaseStatusBadges(
              statusLabel: 'Disetujui',
              terverifikasi: true,
              selesai: false,
            ),
          ),
        ),
      ),
    );

    final pills = tester
        .widgetList<StatusPill>(find.byType(StatusPill))
        .toList();
    expect(pills, hasLength(2));
    expect(pills.first.color, AppColors.dark.success);
    expect(pills.last.color, AppColors.dark.success);
  });

  testWidgets('detail menampilkan aksi saat bisaSelesaikan true', (
    tester,
  ) async {
    final repo = _FakeRitaseRepository(bisaSelesaikan: true, selesai: false);

    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Selesaikan Ritase'), findsOneWidget);
    expect(find.byType(StickyActionBar), findsOneWidget);
    expect(find.text('Selesai'), findsNothing);
  });

  testWidgets('detail menyembunyikan aksi saat bisaSelesaikan false', (
    tester,
  ) async {
    final repo = _FakeRitaseRepository(bisaSelesaikan: false, selesai: true);

    await tester.pumpWidget(_detailApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('Selesaikan Ritase'), findsNothing);
    expect(find.byType(StickyActionBar), findsNothing);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.text('Terverifikasi'), findsOneWidget);
  });

  for (final size in _viewSizes) {
    testWidgets(
      'detail ritase dan aksi utama muat di ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        _setView(tester, size);
        final repo = _FakeRitaseRepository(
          bisaSelesaikan: true,
          selesai: false,
        );

        await tester.pumpWidget(_detailApp(repo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DetailRitaseScreen), findsOneWidget);
        final content = _boundedContent();
        expect(content, findsOneWidget);
        final contentRect = tester.getRect(content);
        final available = size.width - (AppSpacing.md * 2);
        final expectedWidth =
            available < AppBreakpoints.maxContentWidth - (AppSpacing.md * 2)
            ? available
            : AppBreakpoints.maxContentWidth - (AppSpacing.md * 2);
        expect(contentRect.width, closeTo(expectedWidth, 1));
        expect(contentRect.left, greaterThanOrEqualTo(0));
        expect(contentRect.right, lessThanOrEqualTo(size.width + 1));

        expect(find.text('Selesaikan Ritase'), findsOneWidget);
        final rect = tester.getRect(find.text('Selesaikan Ritase'));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width + 1));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height + 1));

        await tester.tap(find.text('Selesaikan Ritase'));
        await tester.pumpAndSettle();

        expect(repo.selesaiIds, ['ritase-1']);
        expect(find.text('Selesaikan Ritase'), findsNothing);
      },
    );
  }
}
