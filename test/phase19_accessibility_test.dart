import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/widgets/app_empty_state.dart';
import 'package:sbps_mobile/shared/widgets/key_value_row.dart';
import 'package:sbps_mobile/shared/widgets/status_pill.dart';
import 'package:sbps_mobile/shared/widgets/sticky_action_bar.dart';
import 'package:sbps_mobile/shared/widgets/submit_spinner.dart';

/// PHASE 19 — ACCESSIBILITY + PERFORMANCE + RESPONSIVE.
///
/// Fokus pengujian perilaku yang dapat direproduksi di lingkungan test:
/// - warna teks yang kontras (StatusPill filled amber → teks gelap),
/// - spinner tombol disabled memakai `disabledForeground` (bukan putih),
/// - touch target ≥48dp pada StickyActionBar,
/// - tooltip salin pada KeyValueRow,
/// - subtitle empty-state memakai onSurfaceVariant (bukan outline),
/// - siklus outbox kosong / backoff TIDAK memanggil `onSyncCycleDone`
///   (menghindari fetch jaringan tiap menit).
void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );

  group('StatusPill — kontras teks filled (Phase 19)', () {
    testWidgets('amber terang memakai teks gelap', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatusPill(
            label: 'Pending',
            color: Color(0xFFF59E0B),
            filled: true,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Pending'));
      expect(text.style!.color, const Color(0xFF0F172A));
    });

    testWidgets('merah tua tetap memakai teks putih', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatusPill(
            label: 'Gagal',
            color: Color(0xFFDC2626),
            filled: true,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Gagal'));
      expect(text.style!.color, Colors.white);
    });

    testWidgets('label dibatasi satu baris dengan ellipsis', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatusPill(label: 'Selesai Dikerjakan Hari Ini', color: Colors.blue),
        ),
      );

      final text = tester.widget<Text>(find.text('Selesai Dikerjakan Hari Ini'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  group('SubmitSpinner — terbaca di tombol disabled (Phase 19)', () {
    testWidgets('memakai ukuran & stroke yang diminta', (tester) async {
      await tester.pumpWidget(wrap(const SubmitSpinner(size: 18, strokeWidth: 3)));

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.strokeWidth, 3);
      expect(tester.getSize(find.byType(CircularProgressIndicator)), const Size(18, 18));
    });

    testWidgets('warnanya BUKAN putih (disabled foreground α38%)', (tester) async {
      await tester.pumpWidget(wrap(const SubmitSpinner()));

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, isNot(Colors.white));
      expect(indicator.color!.a, closeTo(0.38, 0.01));
    });
  });

  group('StickyActionBar — touch target ≥48dp (Phase 19)', () {
    testWidgets('tombol utama minimal 48dp walau text scale 130%', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: StickyActionBar(
                  primaryLabel: 'Simpan',
                  onPrimary: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(
        find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('mode loading memakai SubmitSpinner', (tester) async {
      await tester.pumpWidget(
        wrap(
          Align(
            alignment: Alignment.bottomCenter,
            child: StickyActionBar(
              primaryLabel: 'Kirim',
              showPrimaryLoading: true,
              onPrimary: () {},
            ),
          ),
        ),
      );

      expect(find.byType(SubmitSpinner), findsOneWidget);
    });
  });

  group('KeyValueRow — aksi salin aksesibel (Phase 19)', () {
    testWidgets('tooltip "Salin <label>" tersedia', (tester) async {
      await tester.pumpWidget(
        wrap(
          const KeyValueRow(
            label: 'Nomor Rangka',
            value: 'MH1234',
            copyValue: 'MH1234',
          ),
        ),
      );

      expect(find.byTooltip('Salin Nomor Rangka'), findsOneWidget);
    });
  });

  group('AppEmptyState — teks sekunder kontras (Phase 19)', () {
    testWidgets('subtitle memakai onSurfaceVariant, bukan outline', (tester) async {
      await tester.pumpWidget(
        wrap(
          const AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Belum ada data',
            subtitle: 'Data akan tampil setelah sinkron.',
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Data akan tampil setelah sinkron.'));
      final scheme = Theme.of(
        tester.element(find.text('Data akan tampil setelah sinkron.')),
      ).colorScheme;
      expect(text.style!.color, scheme.onSurfaceVariant);
    });
  });

  group('OutboxSyncService.syncNow — tidak panggil callback saat tak ada aksi', () {
    test('antrean kosong → onSyncCycleDone TIDAK dipanggil', () async {
      final service = OutboxSyncService(_FakeOutboxRepository([]), ApiClient());
      var called = 0;
      service.onSyncCycleDone = () => called++;

      await service.syncNow();

      expect(called, 0);
    });

    test('aksi masih backoff → TIDAK dipanggil', () async {
      final service = OutboxSyncService(
        _FakeOutboxRepository([
          _action(
            'a-1',
            retryCount: 5,
            lastAttemptAt: DateTime.now().subtract(const Duration(seconds: 5)),
          ),
        ]),
        ApiClient(),
      );
      var called = 0;
      service.onSyncCycleDone = () => called++;

      await service.syncNow();

      expect(called, 0);
    });

    test('aksi melewati batas percobaan → TIDAK dipanggil', () async {
      final service = OutboxSyncService(
        _FakeOutboxRepository([_action('a-2', retryCount: 99)]),
        ApiClient(),
      );
      var called = 0;
      service.onSyncCycleDone = () => called++;

      await service.syncNow();

      expect(called, 0);
    });
  });
}

class _FakeOutboxRepository extends OutboxRepository {
  _FakeOutboxRepository(this._actions);

  final List<PendingAction> _actions;

  @override
  Future<List<PendingAction>> pendingActions() async => List.of(_actions);

  @override
  Future<int> countPending() async => _actions.length;
}

PendingAction _action(
  String id, {
  int retryCount = 0,
  DateTime? lastAttemptAt,
}) => PendingAction(
  id: id,
  clientUuid: 'uuid-$id',
  endpoint: PendingEndpoint.servisAjuan,
  payloadJson: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  idempotencyKey: 'idem-$id',
  retryCount: retryCount,
  lastAttemptAt: lastAttemptAt,
);
