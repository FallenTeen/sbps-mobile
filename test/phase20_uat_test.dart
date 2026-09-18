import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/api_response.dart';
import 'package:sbps_mobile/core/device_info_service.dart';
import 'package:sbps_mobile/core/draft/autosave_controller.dart';
import 'package:sbps_mobile/core/draft/draft_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';
import 'package:sbps_mobile/core/photo_compression_service.dart';
import 'package:sbps_mobile/features/armada/ritase_model.dart';
import 'package:sbps_mobile/features/auth/auth_providers.dart';
import 'package:sbps_mobile/features/presensi/models/titik.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/theme/breakpoints.dart';
import 'package:sbps_mobile/shared/widgets/adaptive_nav_shell.dart';
import 'package:sbps_mobile/shared/widgets/app_empty_state.dart';
import 'package:sbps_mobile/shared/widgets/bouncing_button.dart';
import 'package:sbps_mobile/shared/widgets/status_pill.dart';
import 'package:sbps_mobile/shared/widgets/sticky_action_bar.dart';
import 'package:sbps_mobile/shared/widgets/submit_spinner.dart';

/// PHASE 20 — UAT + REGRESSION + RELEASE CANDIDATE.
///
/// Skenario UAT yang dapat direproduksi headless. Verifikasi perangkat fisik
/// (kamera, GPS asli, FCM, background service, perangkat low-end) TIDAK di
/// sini — lihat `docs/UAT_REPORT.md` (dicatat BLOCKED).
///
/// Cakupan:
/// - duplicate tap / double submit (BouncingButton + busy-guard provider),
/// - stale GPS ditolak sebelum submit,
/// - submit sukses = tepat satu PendingAction dengan idempotency key,
/// - klasifikasi retry: 4xx permanen, jaringan retryable, lampiran hilang,
/// - partial submission ritase tidak dianggap selesai,
/// - attachment persistence (outbox enqueue/decode/cleanup),
/// - draft persistence + AutosaveController debounce/restore,
/// - dark mode, font 130%, layout tablet.
void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('uat20_hive');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  // ==========================================================================
  // UAT-DRV-01 — Duplicate tap / double submit
  // ==========================================================================
  group('UAT-DRV-01 duplicate tap', () {
    testWidgets('BouncingButton: satu tap = satu aksi (child tidak ikut)', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BouncingButton(
                onPressed: () => taps++,
                child: FilledButton(
                  onPressed: () => taps += 100,
                  child: const Text('Kirim'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(BouncingButton));
      await tester.pumpAndSettle();

      expect(taps, 1, reason: 'child FilledButton tidak boleh ikut terpicu');
    });

    test('PresensiSubmitController: tap kedua saat busy ditolak', () async {
      final compression = _HangingCompression();
      final container = ProviderContainer(
        overrides: [
          selectedTitikProvider.overrideWith(() => _FakeSelectedTitik(_titik)),
          locationProvider.overrideWith(() => _FakeLocation(_fresh)),
          photoCompressionProvider.overrideWithValue(compression),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(presensiSubmitProvider.notifier);
      unawaited(
        controller.submit(
          endpoint: PendingEndpoint.presensiCheckIn,
          photoPath: 'uat.jpg',
        ),
      );

      expect(container.read(presensiSubmitProvider).busy, isTrue);
      final second = await controller.submit(
        endpoint: PendingEndpoint.presensiCheckIn,
        photoPath: 'uat.jpg',
      );

      expect(second.error, 'Sedang memproses.');
      expect(second.delivered, isFalse);
      expect(second.queued, isFalse);
    });
  });

  // ==========================================================================
  // UAT-DRV-02 — Stale GPS ditolak sebelum submit
  // ==========================================================================
  group('UAT-DRV-02 stale GPS', () {
    test('posisi basi ditolak & meminta segarkan lokasi', () async {
      final container = ProviderContainer(
        overrides: [
          selectedTitikProvider.overrideWith(() => _FakeSelectedTitik(_titik)),
          locationProvider.overrideWith(() => _FakeLocation(_stale)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(presensiSubmitProvider.notifier)
          .submit(
            endpoint: PendingEndpoint.presensiCheckIn,
            photoPath: 'uat.jpg',
          );

      expect(result.error, contains('lama'));
      expect(result.delivered, isFalse);
      expect(result.queued, isFalse);
    });

    test('tanpa posisi ditolak & meminta tunggu GPS', () async {
      final container = ProviderContainer(
        overrides: [
          selectedTitikProvider.overrideWith(() => _FakeSelectedTitik(_titik)),
          locationProvider.overrideWith(
            () => _FakeLocation(const LocationSnapshot()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(presensiSubmitProvider.notifier)
          .submit(
            endpoint: PendingEndpoint.presensiCheckIn,
            photoPath: 'uat.jpg',
          );

      expect(result.error, contains('belum tersedia'));
    });
  });

  // ==========================================================================
  // UAT-DRV-03 — Submit sukses = satu aksi, idempoten
  // ==========================================================================
  group('UAT-DRV-03 submit sukses', () {
    test('tepat satu PendingAction terkirim dengan idempotency key', () async {
      final repo = _DeliveringOutboxRepository();
      final container = ProviderContainer(
        overrides: [
          selectedTitikProvider.overrideWith(() => _FakeSelectedTitik(_titik)),
          locationProvider.overrideWith(() => _FakeLocation(_fresh)),
          photoCompressionProvider.overrideWithValue(_PassthroughCompression()),
          deviceInfoProvider.overrideWithValue(_FakeDeviceInfo()),
          outboxRepositoryProvider.overrideWithValue(repo),
          outboxSyncServiceProvider.overrideWithValue(_dummySync(repo)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(presensiSubmitProvider.notifier)
          .submit(
            endpoint: PendingEndpoint.presensiCheckIn,
            photoPath: 'uat.jpg',
          );

      expect(result.delivered, isTrue);
      expect(repo.enqueued, hasLength(1));
      final action = repo.enqueued.single;
      expect(action.endpoint, PendingEndpoint.presensiCheckIn);
      expect(action.photoLocalPath, 'uat.jpg');
      expect(action.idempotencyKey, isNotEmpty);
      expect(action.clientUuid, isNotEmpty);
      expect(action.payloadJson['device_id'], 'uat-device');
    });
  });

  // ==========================================================================
  // UAT-SYNC-01 — Klasifikasi retry / failed sync
  // ==========================================================================
  group('UAT-SYNC-01 klasifikasi retry', () {
    test('4xx → permanentlyFailed (tidak diulang otomatis)', () async {
      final service = _syncWith(_FakeApiClient(_FakeMode.reject4xx));
      final result = await service.send(
        _action(
          'a-4xx',
          PendingEndpoint.presensiCheckOut,
          photoLocalPath: '/uat/foto.jpg',
        ),
      );

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isTrue);
    });

    test('jaringan putus → retryable (queued, bukan failed)', () async {
      final service = _syncWith(_FakeApiClient(_FakeMode.network));
      final result = await service.send(
        _action(
          'a-net',
          PendingEndpoint.presensiCheckOut,
          photoLocalPath: '/uat/foto.jpg',
        ),
      );

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isFalse);
    });

    test('lampiran hilang → permanen dengan instruksi ambil ulang', () async {
      final service = _syncWith(_FakeApiClient(_FakeMode.missingFile));
      final result = await service.send(
        _action(
          'a-file',
          PendingEndpoint.presensiCheckOut,
          photoLocalPath: '/hilang/foto.jpg',
        ),
      );

      expect(result.permanentlyFailed, isTrue);
      expect(result.errorMessage, contains('lampiran'));
    });
  });

  // ==========================================================================
  // UAT-PARTIAL-01 — Partial submission (ritase)
  // ==========================================================================
  group('UAT-PARTIAL-01 partial submission', () {
    test('sebagian record terkirim TIDAK dianggap selesai', () {
      final summary = summaryRitase([
        _ritase(1, RitaseRecordStatus.synced),
        _ritase(2, RitaseRecordStatus.queued),
        _ritase(3, RitaseRecordStatus.failed),
      ]);

      expect(summary.syncedCount, 1);
      expect(summary.allSynced, isFalse);
      expect(summary.hasPending, isTrue);
    });

    test('record queued yang gagal permanen tetap failed (bukan synced)', () {
      final queued = _ritase(1, RitaseRecordStatus.queued);
      final reconciled = reconcileRecordStatus(queued, {
        queued.clientUuid: PendingStatus.failed,
      });

      expect(reconciled.status, RitaseRecordStatus.failed);
    });
  });

  // ==========================================================================
  // UAT-ATTACH-01 — Attachment persistence (outbox)
  // ==========================================================================
  group('UAT-ATTACH-01 attachment persistence', () {
    test('encode/decode mempertahankan path lampiran', () {
      final action = _action(
        'a-enc',
        PendingEndpoint.formulirSubmit,
        photoLocalPaths: const ['/tmp/a.jpg', '/tmp/b.jpg'],
      );

      final restored = PendingAction.decode(action.encode());

      expect(restored.photoLocalPaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
    });

    test('gagal retryable: file tetap ada, aksi tetap pending', () async {
      final file = _tempFile('retry.jpg');
      final repo = OutboxRepository(
        boxName: 'uat_attach_retry_${DateTime.now().microsecondsSinceEpoch}',
      );
      final action = _action(
        'a-retry',
        PendingEndpoint.presensiCheckIn,
        photoLocalPath: file.path,
      );

      await repo.enqueue(
        action,
        (_) async =>
            const OutboxSendResult(delivered: false, errorMessage: 'offline'),
      );

      final pending = await repo.pendingActions();
      expect(pending.single.status, PendingStatus.pending);
      expect(pending.single.retryCount, 1);
      expect(file.existsSync(), isTrue, reason: 'foto belum boleh dihapus');
    });

    test('gagal permanen: file tetap ada, status failed', () async {
      final file = _tempFile('failed.jpg');
      final repo = OutboxRepository(
        boxName: 'uat_attach_failed_${DateTime.now().microsecondsSinceEpoch}',
      );
      final action = _action(
        'a-fail',
        PendingEndpoint.presensiCheckIn,
        photoLocalPath: file.path,
      );

      await repo.enqueue(
        action,
        (_) async => const OutboxSendResult(
          delivered: false,
          permanentlyFailed: true,
          errorMessage: '422',
        ),
      );

      final pending = await repo.pendingActions();
      expect(pending.single.status, PendingStatus.failed);
      expect(file.existsSync(), isTrue);
    });

    test('berhasil: aksi & file lampiran dibersihkan', () async {
      final file = _tempFile('delivered.jpg');
      final repo = OutboxRepository(
        boxName: 'uat_attach_ok_${DateTime.now().microsecondsSinceEpoch}',
      );
      final action = _action(
        'a-ok',
        PendingEndpoint.presensiCheckIn,
        photoLocalPath: file.path,
      );

      final result = await repo.enqueue(
        action,
        (_) async => const OutboxSendResult(delivered: true),
      );

      expect(result.delivered, isTrue);
      expect(await repo.pendingActions(), isEmpty);
      expect(file.existsSync(), isFalse, reason: 'foto dibersihkan setelah sukses');
    });
  });

  // ==========================================================================
  // UAT-DRAFT-01 — Draft persistence + restoration
  // ==========================================================================
  group('UAT-DRAFT-01 draft restoration', () {
    test('DraftRepository: simpan → muat mempertahankan field & foto', () async {
      final repo = DraftRepository(
        boxName: 'uat_draft_${DateTime.now().microsecondsSinceEpoch}',
      );
      await repo.save(
        draftKey: 'uat_key',
        formType: DraftFormType.formulirLapangan,
        fieldsJson: const {'catatan': 'isi UAT', 'lokasi': 'blok A'},
        photoLocalPaths: const ['/tmp/uat.jpg'],
      );

      final draft = await repo.load('uat_key');

      expect(draft, isNotNull);
      expect(draft!.fieldsJson['catatan'], 'isi UAT');
      expect(draft.photoLocalPaths, ['/tmp/uat.jpg']);
    });

    testWidgets('AutosaveController: debounce simpan & restore callback', (
      tester,
    ) async {
      final repo = _RecordingDraftRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [draftRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: _AutosaveHost()),
        ),
      );
      final host = tester.state<_AutosaveHostState>(
        find.byType(_AutosaveHost),
      );

      host.autosave.onFieldChanged();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.saved, isEmpty, reason: 'belum lewat debounce 800ms');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single['catatan'], 'isi UAT');
      expect(repo.savedPhotos.single, ['/tmp/uat.jpg']);

      repo.seeded = FormDraft(
        draftKey: 'uat_draft',
        formType: DraftFormType.formulirLapangan,
        fieldsJson: const {'catatan': 'draft lama'},
        photoLocalPaths: const ['/tmp/uat.jpg'],
        savedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );

      final restored = await host.autosave.load();
      expect(restored, isTrue);
      expect(host.restored?.fieldsJson['catatan'], 'draft lama');
    });
  });

  // ==========================================================================
  // UAT-UI-01 — Dark mode / font 130% / tablet
  // ==========================================================================
  group('UAT-UI-01 dark mode', () {
    testWidgets('widget bersama render di dark theme tanpa overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ListView(
              children: const [
                AppEmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Belum ada data',
                  subtitle: 'Menunggu sinkron.',
                ),
                StatusPill(
                  label: 'Menunggu',
                  color: Color(0xFFF59E0B),
                  filled: true,
                ),
                SubmitSpinner(),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final context = tester.element(find.text('Belum ada data'));
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });

  group('UAT-UI-02 font 130%', () {
    testWidgets('AdaptiveNavShell compact tidak overflow pada 130%', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        width: 400,
        textScale: 1.3,
        child: AdaptiveNavShell(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Text('Konten'),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StickyActionBar tetap ≥48dp pada 130%', (tester) async {
      await _pumpAtSize(
        tester,
        width: 400,
        textScale: 1.3,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: StickyActionBar(primaryLabel: 'Simpan', onPrimary: () {}),
        ),
      );

      final size = tester.getSize(
        find.byWidgetPredicate((w) => w is FilledButton),
      );
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  });

  group('UAT-UI-03 tablet layout', () {
    testWidgets('expanded 1000px memakai NavigationRail extended', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        width: 1000,
        child: AdaptiveNavShell(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Text('Konten'),
        ),
      );

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ResponsiveCenter membatasi lebar form di tablet', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        width: 1000,
        child: const ResponsiveCenter(child: SizedBox(height: 20)),
      );

      final box = tester.widget<ConstrainedBox>(
        find
            .descendant(
              of: find.byType(ResponsiveCenter),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.constraints.maxWidth, AppBreakpoints.maxFormWidth);
      expect(tester.takeException(), isNull);
    });

    testWidgets('medium 700px memakai NavigationRail (non-extended)', (
      tester,
    ) async {
      await _pumpAtSize(
        tester,
        width: 700,
        child: AdaptiveNavShell(
          currentIndex: 0,
          onDestinationSelected: (_) {},
          destinations: _destinations,
          child: const Text('Konten'),
        ),
      );

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Data & helper
// ---------------------------------------------------------------------------

const _titik = Titik(
  id: 't-1',
  nama: 'Titik UAT',
  latitude: -6.2,
  longitude: 106.8,
  radiusPresensiMeter: 100,
);

Position _pos(DateTime ts) => Position(
  latitude: -6.2,
  longitude: 106.8,
  timestamp: ts,
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

final _fresh = LocationSnapshot(
  position: _pos(DateTime.now()),
  acquiredAt: DateTime.now(),
);

final _stale = LocationSnapshot(
  position: _pos(DateTime.now().subtract(const Duration(minutes: 20))),
  acquiredAt: DateTime.now().subtract(const Duration(minutes: 20)),
);

final _destinations = [
  const AdaptiveNavDestination(
    key: 'produksi',
    label: 'Produksi',
    icon: Icons.factory_outlined,
    selectedIcon: Icons.factory,
  ),
  const AdaptiveNavDestination(
    key: 'qc',
    label: 'QC',
    icon: Icons.science_outlined,
    selectedIcon: Icons.science,
  ),
  const AdaptiveNavDestination(
    key: 'armada',
    label: 'Armada',
    icon: Icons.local_shipping_outlined,
    selectedIcon: Icons.local_shipping,
  ),
];

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

PendingAction _action(
  String id,
  PendingEndpoint endpoint, {
  String? photoLocalPath,
  List<String> photoLocalPaths = const [],
}) => PendingAction(
  id: id,
  clientUuid: 'uuid-$id',
  endpoint: endpoint,
  payloadJson: const {'titik_id': 't-1'},
  photoLocalPath: photoLocalPath,
  photoLocalPaths: photoLocalPaths,
  createdAt: DateTime.utc(2026, 9, 18),
  idempotencyKey: 'idem-$id',
);

RitaseRecord _ritase(int index, RitaseRecordStatus status) => RitaseRecord(
  id: 'r-$index',
  index: index,
  armadaId: 'a-1',
  jumlah: 1,
  satuan: 'rit',
  createdAt: DateTime(2026, 9, 18, 8),
  status: status,
  clientUuid: 'cu-$index',
  idempotencyKey: 'ik-$index',
);

File _tempFile(String name) {
  final dir = Directory.systemTemp.createTempSync('uat20_file');
  final file = File('${dir.path}/$name')..writeAsStringSync('binary');
  return file;
}

OutboxSyncService _syncWith(ApiClient api) => OutboxSyncService(
  _NoopOutboxRepository(),
  api,
  connectivityStream: () => const Stream.empty(),
);

OutboxSyncService _dummySync(OutboxRepository repo) => OutboxSyncService(
  repo,
  _FakeApiClient(),
  connectivityStream: () => const Stream.empty(),
);

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

enum _FakeMode { deliver, reject4xx, network, missingFile }

class _FakeApiClient extends ApiClient {
  _FakeApiClient([this.mode = _FakeMode.deliver]);

  final _FakeMode mode;

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    _maybeThrow();
    return const ApiResponse(status: 'success', message: 'ok');
  }

  @override
  Future<ApiResponse<T>> postMultipart<T>(
    String path, {
    Map<String, String> fields = const {},
    required List<MultipartFileSpec> files,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    _maybeThrow();
    return const ApiResponse(status: 'success', message: 'ok');
  }

  void _maybeThrow() {
    switch (mode) {
      case _FakeMode.deliver:
        return;
      case _FakeMode.reject4xx:
        throw ApiException('Data tidak valid', statusCode: 422);
      case _FakeMode.network:
        throw ApiException('Tidak dapat terhubung ke server');
      case _FakeMode.missingFile:
        throw const FileSystemException('file tidak ada');
    }
  }
}

class _NoopOutboxRepository extends OutboxRepository {
  final List<String> removed = [];
  final List<String> failed = [];
  final List<String> retried = [];
  final List<PendingAction> pending = [];

  @override
  Future<void> markSyncing(String id) async {}

  @override
  Future<void> markRetryable(String id, String? message) async =>
      retried.add(id);

  @override
  Future<void> markFailed(String id, String? message) async => failed.add(id);

  @override
  Future<void> remove(String id) async => removed.add(id);

  @override
  Future<List<PendingAction>> pendingActions() async => List.of(pending);

  @override
  Future<int> countPending() async => pending.length;
}

class _DeliveringOutboxRepository extends OutboxRepository {
  final List<PendingAction> enqueued = [];

  @override
  Future<OutboxSendResult> enqueue(
    PendingAction action,
    Future<OutboxSendResult> Function(PendingAction) send,
  ) async {
    enqueued.add(action);
    return const OutboxSendResult(
      delivered: true,
      responseData: {'status_validasi': 'dalam_radius'},
    );
  }
}

class _FakeSelectedTitik extends SelectedTitikNotifier {
  _FakeSelectedTitik(this.titik);

  final Titik titik;

  @override
  Titik? build() => titik;
}

class _FakeLocation extends LocationController {
  _FakeLocation(this.snapshot);

  final LocationSnapshot snapshot;

  @override
  LocationSnapshot build() => snapshot;
}

class _PassthroughCompression extends PhotoCompressionService {
  @override
  Future<String> compress(String sourcePath) async => sourcePath;
}

class _HangingCompression extends PhotoCompressionService {
  final Completer<String> _completer = Completer<String>();

  @override
  Future<String> compress(String sourcePath) => _completer.future;
}

class _FakeDeviceInfo extends DeviceInfoService {
  @override
  String get name => 'uat-device';
}

class _RecordingDraftRepository extends DraftRepository {
  final List<Map<String, dynamic>> saved = [];
  final List<List<String>> savedPhotos = [];
  FormDraft? seeded;

  @override
  Future<void> save({
    required String draftKey,
    required DraftFormType formType,
    required Map<String, dynamic> fieldsJson,
    List<String> photoLocalPaths = const [],
    int? currentStep,
    DateTime? savedAt,
  }) async {
    saved.add(fieldsJson);
    savedPhotos.add(photoLocalPaths);
  }

  @override
  Future<FormDraft?> load(String draftKey) async => seeded;

  @override
  Future<void> delete(String draftKey) async {
    seeded = null;
  }
}

class _AutosaveHost extends ConsumerStatefulWidget {
  const _AutosaveHost();

  @override
  ConsumerState<_AutosaveHost> createState() => _AutosaveHostState();
}

class _AutosaveHostState extends ConsumerState<_AutosaveHost> {
  late final AutosaveController autosave;
  FormDraft? restored;

  @override
  void initState() {
    super.initState();
    autosave = AutosaveController(
      ref: ref,
      draftKey: 'uat_draft',
      formType: DraftFormType.formulirLapangan,
      currentFields: () => const {'catatan': 'isi UAT'},
      currentPhotoPaths: () => const ['/tmp/uat.jpg'],
      onRestore: (draft) => restored = draft,
    )..init();
  }

  @override
  void dispose() {
    autosave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
