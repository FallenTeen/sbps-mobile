import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/api_response.dart';
import 'package:sbps_mobile/core/draft/draft_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';
import 'package:sbps_mobile/features/outbox/data_belum_terkirim_screen.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/features/proyek/pending_summary_provider.dart';

/// PHASE 17 — OFFLINE / OUTBOX / DRAFT HARDENING.
///
/// Fokus: status yang jujur (Queued != Synced), retry/backoff yang tidak
/// mengubah "menunggu" jadi "gagal", endpoint baru via outbox (ajuan servis,
/// foto todo workshop, request sparepart), dan pembersihan draft bersih
/// (entri + file foto).
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('phase17');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Endpoint outbox baru (v17)', () {
    test('servisAjuan = POST /servis-armada (JSON)', () {
      const e = PendingEndpoint.servisAjuan;

      expect(e.path, '/servis-armada');
      expect(e.isJson, isTrue);
      expect(e.isUploadMedia, isFalse);
    });

    test('workshopTodoPhoto = multipart path dinamis, bukan JSON', () {
      const e = PendingEndpoint.workshopTodoPhoto;

      expect(e.path, '/workshop/job/{id}/todo/{todoId}/photo');
      expect(e.isJson, isFalse);
      expect(e.isUploadMedia, isFalse);
    });

    test('workshopRequestSparepart = JSON path dinamis', () {
      const e = PendingEndpoint.workshopRequestSparepart;

      expect(e.path, '/workshop/job/{id}/request-sparepart');
      expect(e.isJson, isTrue);
    });

    test('jumlah endpoint terdaftar = 19 (19 dari 16 lama + 3 baru)', () {
      expect(PendingEndpoint.values, hasLength(19));
    });

    test('roundtrip servisAjuan mempertahankan payloadData items', () {
      final action = PendingAction(
        id: 'a-1',
        clientUuid: 'uuid-1',
        endpoint: PendingEndpoint.servisAjuan,
        payloadJson: const {},
        payloadData: {
          'armada_id': 'arm-1',
          'keluhan': 'Ban bocor',
          'kategori': 'ringan',
        },
        createdAt: DateTime.utc(2026, 1, 1),
        idempotencyKey: 'idem-1',
      );

      final decoded = PendingAction.decode(action.encode());

      expect(decoded.endpoint, PendingEndpoint.servisAjuan);
      expect(decoded.payloadData['armada_id'], 'arm-1');
      expect(decoded.clientUuid, 'uuid-1');
    });

    test('roundtrip workshopTodoPhoto mempertahankan job/todo + foto', () {
      final action = PendingAction(
        id: 'a-2',
        clientUuid: 'uuid-2',
        endpoint: PendingEndpoint.workshopTodoPhoto,
        payloadJson: {'job_id': 'job-9', 'todo_id': 'todo-3'},
        photoLocalPath: '/tmp/foto.jpg',
        createdAt: DateTime.utc(2026, 1, 1),
        idempotencyKey: 'idem-2',
      );

      final decoded = PendingAction.decode(action.encode());

      expect(decoded.payloadJson['job_id'], 'job-9');
      expect(decoded.payloadJson['todo_id'], 'todo-3');
      expect(decoded.photoLocalPath, '/tmp/foto.jpg');
      expect(decoded.endpoint.isJson, isFalse);
    });
  });

  group('Semantik status (OutboxRepository asli + Hive)', () {
    late OutboxRepository repo;

    setUp(() async {
      repo = OutboxRepository(boxName: 'phase17_status');
      await (await Hive.openBox<String>('phase17_status')).clear();
    });

    test('enqueue error 4xx permanen → status failed ("Gagal dikirim")', () async {
      final result = await repo.enqueue(
        _action('k-1', PendingEndpoint.servisAjuan),
        (_) async => const OutboxSendResult(
          delivered: false,
          permanentlyFailed: true,
          errorMessage: 'Data tidak valid',
        ),
      );
      final list = await repo.pendingActions();

      expect(result.permanentlyFailed, isTrue);
      expect(list, hasLength(1));
      expect(list.first.status, PendingStatus.failed);
      expect(list.first.retryCount, 1);
      expect(list.first.errorMessage, 'Data tidak valid');
    });

    test('enqueue offline/5xx → status TETAP pending ("Menunggu jaringan"), retryable', () async {
      final result = await repo.enqueue(
        _action('k-2', PendingEndpoint.servisAjuan),
        (_) async => const OutboxSendResult(
          delivered: false,
          errorMessage: 'Tidak dapat terhubung ke server',
        ),
      );
      final list = await repo.pendingActions();

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isFalse);
      expect(list.first.status, PendingStatus.pending, reason: 'Queued != Synced');
      expect(list.first.retryCount, 1);
      expect(list.first.errorMessage, 'Tidak dapat terhubung ke server');
    });

    test('enqueue delivered → aksi dihapus dari antrean', () async {
      final result = await repo.enqueue(
        _action('k-3', PendingEndpoint.servisAjuan),
        (_) async => const OutboxSendResult(delivered: true),
      );
      final list = await repo.pendingActions();

      expect(result.delivered, isTrue);
      expect(list, isEmpty);
    });

    test('markRetryable memperbarui backoff TANPA mengubah status jadi failed', () async {
      await repo.enqueue(
        _action('k-4', PendingEndpoint.workshopRequestSparepart),
        (_) async => const OutboxSendResult(delivered: false),
      );
      final before = (await repo.pendingActions()).first;
      final sentAt = before.lastAttemptAt;

      await repo.markRetryable('k-4', 'coba lagi');

      final after = (await repo.pendingActions()).first;
      expect(after.status, PendingStatus.pending);
      expect(after.retryCount, before.retryCount + 1);
      expect(after.lastAttemptAt, isNot(sentAt));
      expect(after.errorMessage, 'coba lagi');
    });

    test('markFailed menandai permanen + menghitung retry', () async {
      await repo.enqueue(
        _action('k-5', PendingEndpoint.workshopRequestSparepart),
        (_) async => const OutboxSendResult(delivered: false),
      );

      await repo.markFailed('k-5', 'konflik 409');

      final after = (await repo.pendingActions()).first;
      expect(after.status, PendingStatus.failed);
      expect(after.retryCount, 2);
      expect(after.errorMessage, 'konflik 409');
    });

    test('pendingActions mengecualikan sukses & mengurutkan createdAt naik', () async {
      final box = await Hive.openBox<String>('phase17_status');
      await box.put(
        'suc',
        _action(
          'suc',
          PendingEndpoint.armadaRitase,
          status: PendingStatus.success,
          createdAt: DateTime.utc(2026, 1, 7),
        ).encode(),
      );
      await box.put(
        'late',
        _action(
          'late',
          PendingEndpoint.armadaRitase,
          createdAt: DateTime.utc(2026, 1, 5),
        ).encode(),
      );
      await box.put(
        'early',
        _action(
          'early',
          PendingEndpoint.armadaRitase,
          createdAt: DateTime.utc(2026, 1, 3),
        ).encode(),
      );

      final list = await repo.pendingActions();

      expect(list.map((a) => a.id).toList(), ['early', 'late']);
    });
  });

  group('OutboxSyncService.send — path & autentikasi per endpoint', () {
    late _FakeApiClient api;
    late OutboxRepository repo;
    late OutboxSyncService service;

    setUp(() async {
      api = _FakeApiClient(mode: _FakeMode.deliver);
      repo = OutboxRepository(boxName: 'phase17_send');
      service = OutboxSyncService(repo, api);
      await (await Hive.openBox<String>('phase17_send')).clear();
    });

    test('servisAjuan: POST /servis-armada JSON + client_uuid + Idempotency-Key', () async {
      final action = _action(
        's-1',
        PendingEndpoint.servisAjuan,
        payloadData: {
          'armada_id': 'arm-9',
          'keluhan': 'Ban bocor',
          'kategori': 'ringan',
        },
        idempotencyKey: 'idem-s1',
      );

      final result = await service.send(action);

      expect(result.delivered, isTrue);
      expect(api.jsonCalls, hasLength(1));
      final call = api.jsonCalls.single;
      expect(call.path, '/servis-armada');
      expect(call.body!['armada_id'], 'arm-9');
      expect(call.body!['keluhan'], 'Ban bocor');
      expect(call.body!['client_uuid'], action.clientUuid);
      expect(call.headers!['Idempotency-Key'], 'idem-s1');
    });

    test('workshopRequestSparepart: path dinamis {id} + job_id DIHAPUS dari body', () async {
      final action = _action(
        's-2',
        PendingEndpoint.workshopRequestSparepart,
        payloadData: {
          'job_id': 'job-42',
          'items': [
            {'nama_barang': 'Oli', 'jumlah': 2},
          ],
        },
        idempotencyKey: 'idem-s2',
      );

      final result = await service.send(action);

      expect(result.delivered, isTrue);
      final call = api.jsonCalls.single;
      expect(call.path, '/workshop/job/job-42/request-sparepart');
      expect(call.body!['job_id'], isNull);
      expect(call.body!['items'], isA<List<dynamic>>());
      expect(call.body!['client_uuid'], action.clientUuid);
      expect(call.headers!['Idempotency-Key'], 'idem-s2');
    });

    test('workshopTodoPhoto: multipart path dinamis + field form + file photo', () async {
      final action = _action(
        's-3',
        PendingEndpoint.workshopTodoPhoto,
        payloadJson: {'job_id': 'job-7', 'todo_id': 'todo-11'},
        photoLocalPath: '/tmp/bukti.jpg',
        idempotencyKey: 'idem-s3',
      );

      final result = await service.send(action);

      expect(result.delivered, isTrue);
      final call = api.multipartCalls.single;
      expect(call.path, '/workshop/job/job-7/todo/todo-11/photo');
      expect(call.fields!['job_id'], 'job-7');
      expect(call.fields!['todo_id'], 'todo-11');
      expect(call.files, hasLength(1));
      expect(call.files.single.field, 'photo');
      expect(call.headers!['Idempotency-Key'], 'idem-s3');
    });

    test('workshopTodoPhoto tanpa foto → permanen gagal (attachment hilang)', () async {
      final action = _action(
        's-4',
        PendingEndpoint.workshopTodoPhoto,
        payloadJson: {'job_id': 'job-7', 'todo_id': 'todo-11'},
      );

      final result = await service.send(action);

      expect(result.permanentlyFailed, isTrue);
      expect(api.multipartCalls, isEmpty);
    });

    test('4xx → permanentlyFailed (tidak akan membaik dengan retry)', () async {
      api.mode = _FakeMode.reject4xx;
      final result = await service
          .send(_action('s-5', PendingEndpoint.servisAjuan, payloadData: const {}));

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isTrue);
    });

    test('jaringan putus → retryable, bukan permanen', () async {
      api.mode = _FakeMode.network;
      final result = await service
          .send(_action('s-6', PendingEndpoint.servisAjuan, payloadData: const {}));

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isFalse);
    });
  });

  group('syncNow — backoff & override manual', () {
    late _FakeApiClient api;
    late OutboxRepository repo;
    late OutboxSyncService service;

    setUp(() async {
      api = _FakeApiClient(mode: _FakeMode.deliver);
      repo = OutboxRepository(boxName: 'phase17_backoff');
      service = OutboxSyncService(repo, api);
      await (await Hive.openBox<String>('phase17_backoff')).clear();
    });

    Future<void> _seed(PendingAction action) async {
      final box = await Hive.openBox<String>('phase17_backoff');
      await box.put(action.id, action.encode());
    }

    test('aksa pending yang baru diantre dikirim pada siklus default', () async {
      await _seed(
        _action('b-0', PendingEndpoint.armadaRitase),
      );

      await service.syncNow();

      expect(await repo.pendingActions(), isEmpty);
    });

    test('aksa dalam backoff (lastAttemptAt baru) TIDAK dikirim default, TERKIRIM saat ignoreBackoff', () async {
      await _seed(
        _action(
          'b-1',
          PendingEndpoint.armadaRitase,
          status: PendingStatus.pending,
          retryCount: 1,
          lastAttemptAt: DateTime.now(),
        ),
      );

      await service.syncNow();
      expect((await repo.pendingActions()).map((a) => a.id), ['b-1'],
          reason: 'masih backoff → dilewati');

      await service.syncNow(ignoreBackoff: true);
      expect(await repo.pendingActions(), isEmpty,
          reason: 'retry manual melewati backoff');
    });

    test('aksa melewati batas maks otomatis (retryCount >= 5) baru dikirim lewat force', () async {
      await _seed(
        _action(
          'b-2',
          PendingEndpoint.armadaRitase,
          status: PendingStatus.pending,
          retryCount: 5,
          lastAttemptAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      );

      await service.syncNow();
      expect((await repo.pendingActions()).map((a) => a.id), ['b-2']);

      await service.syncNow(ignoreBackoff: true);
      expect(await repo.pendingActions(), isEmpty);
    });
  });

  group('PendingSummary buckets endpoint baru', () {
    test('armadaCount mencakup servisAjuan', () async {
      final repo = _FakeOutboxRepository([
        _action('x1', PendingEndpoint.servisAjuan),
        _action('x2', PendingEndpoint.armadaRitase),
      ]);
      final counts = await PendingSummary(repository: repo).getSummary('Driver Armada');

      expect(counts.armada, 2);
    });

    test('workshopCount mencakup workshopTodoPhoto + workshopRequestSparepart, BUKAN servisAjuan', () async {
      final repo = _FakeOutboxRepository([
        _action('x1', PendingEndpoint.workshopTodoPhoto),
        _action('x2', PendingEndpoint.workshopRequestSparepart),
        _action('x3', PendingEndpoint.servisAjuan), // masuk armada, bukan workshop
        _action('x4', PendingEndpoint.workshopMulai),
      ]);
      final counts = await PendingSummary(repository: repo).getSummary('Workshop');

      expect(counts.workshop, 3);
      expect(counts.armada, 0, reason: 'role Workshop tak akses armada');
    });
  });

  group('DraftRepository — siklus hidup & pembersihan file', () {
    late DraftRepository repo;

    setUp(() async {
      repo = DraftRepository(boxName: 'phase17_drafts');
      await (await Hive.openBox<String>('phase17_drafts')).clear();
    });

    test('save → load mempertahankan field + foto + step', () async {
      await repo.save(
        draftKey: 'servis_ajuan_arm-1',
        formType: DraftFormType.servisAjuan,
        fieldsJson: {'keluhan': 'Ban bocor', 'kategori': 'ringan'},
        photoLocalPaths: const ['/tmp/a.jpg'],
        currentStep: 2,
      );

      final draft = await repo.load('servis_ajuan_arm-1');

      expect(draft, isNotNull);
      expect(draft!.formType, DraftFormType.servisAjuan);
      expect(draft.fieldsJson['keluhan'], 'Ban bocor');
      expect(draft.photoLocalPaths, ['/tmp/a.jpg']);
      expect(draft.currentStep, 2);
      expect(draft.isExpired, isFalse);
    });

    test('delete menghapus entri', () async {
      await repo.save(
        draftKey: 'k-hapus',
        formType: DraftFormType.formulirLapangan,
        fieldsJson: const {},
      );
      await repo.delete('k-hapus');

      expect(await repo.load('k-hapus'), isNull);
    });

    test('cleanupExpired menghapus entri expired BESERTA file fotonya, menyelamatkan yang masih hidup', () async {
      final expiredPhoto = File('${tempDir.path}/expired.jpg');
      final freshPhoto = File('${tempDir.path}/fresh.jpg');
      expiredPhoto.writeAsStringSync('x');
      freshPhoto.writeAsStringSync('x');

      await repo.save(
        draftKey: 'k-basi',
        formType: DraftFormType.dokumentasi,
        fieldsJson: const {},
        photoLocalPaths: [expiredPhoto.path],
        savedAt: DateTime.now().subtract(const Duration(days: 5)),
      );
      await repo.save(
        draftKey: 'k-fresh',
        formType: DraftFormType.dokumentasi,
        fieldsJson: const {},
        photoLocalPaths: [freshPhoto.path],
      );
      final box = await Hive.openBox<String>('phase17_drafts');
      await box.put('k-korup', 'bukan json');

      final removed = await repo.cleanupExpired();

      expect(removed, 2, reason: 'expired + korup dihapus, fresh tidak');
      expect(await repo.load('k-basi'), isNull);
      expect(await repo.load('k-korup'), isNull);
      expect(await repo.load('k-fresh'), isNotNull);
      expect(expiredPhoto.existsSync(), isFalse);
      expect(freshPhoto.existsSync(), isTrue);
    });
  });

  group('Data Belum Terkirim — status yang jujur', () {
    Widget _wrap(OutboxRepository repo) => ProviderScope(
      overrides: [
        outboxRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: DataBelumTerkirimScreen()),
    );

    testWidgets('aksi failed → "Gagal dikirim" + tombol Hapus/Kirim Ulang', (tester) async {
      final repo = _FakeOutboxRepository([
        _action(
          'f-1',
          PendingEndpoint.servisAjuan,
          status: PendingStatus.failed,
          errorMessage: 'Armada tidak valid',
        ),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Ajuan servis armada'), findsOneWidget);
      expect(find.text('Gagal dikirim'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);
      expect(find.text('Kirim Ulang'), findsOneWidget);
      expect(find.text('Armada tidak valid'), findsOneWidget);
    });

    testWidgets('aksi pending (offline) → "Menunggu jaringan" TANPA tombol retry', (tester) async {
      final repo = _FakeOutboxRepository([
        _action(
          'p-1',
          PendingEndpoint.workshopRequestSparepart,
          status: PendingStatus.pending,
          errorMessage: 'Tidak dapat terhubung ke server',
        ),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Request sparepart workshop'), findsOneWidget);
      expect(find.text('Menunggu jaringan'), findsOneWidget);
      expect(find.text('Kirim Ulang'), findsNothing);
      expect(find.text('Hapus'), findsNothing);
    });

    testWidgets('label endpoint baru tampil di daftar', (tester) async {
      final repo = _FakeOutboxRepository([
        _action('q-1', PendingEndpoint.servisAjuan, status: PendingStatus.pending),
        _action(
          'q-2',
          PendingEndpoint.workshopTodoPhoto,
          status: PendingStatus.pending,
        ),
      ]);

      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Ajuan servis armada'), findsOneWidget);
      expect(find.text('Foto bukti todo workshop'), findsOneWidget);
    });
  });
}

// ── Helper ──────────────────────────────────────────────────────────────────

enum _FakeMode { deliver, reject4xx, network }

class _FakeApiClient extends ApiClient {
  _FakeApiClient({this.mode = _FakeMode.deliver});

  _FakeMode mode;

  final List<({String path, Map<String, dynamic>? body, Map<String, dynamic>? headers})>
      jsonCalls = [];
  final List<
    ({
      String path,
      Map<String, String>? fields,
      List<MultipartFileSpec> files,
      Map<String, dynamic>? headers,
    })
  >
      multipartCalls = [];

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    jsonCalls.add((
      path: path,
      body: body as Map<String, dynamic>?,
      headers: headers,
    ));
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
    multipartCalls.add((
      path: path,
      fields: fields,
      files: files,
      headers: headers,
    ));
    _maybeThrow();
    return const ApiResponse(status: 'success', message: 'ok');
  }

  void _maybeThrow() {
    if (mode == _FakeMode.reject4xx) {
      throw ApiException('Data tidak valid', statusCode: 422);
    }
    if (mode == _FakeMode.network) {
      throw ApiException('Tidak dapat terhubung ke server');
    }
  }
}

class _FakeOutboxRepository extends OutboxRepository {
  _FakeOutboxRepository(List<PendingAction> actions) : _actions = actions;

  final List<PendingAction> _actions;

  @override
  Future<List<PendingAction>> pendingActions() async => List.of(_actions);

  @override
  Future<int> countPending() async => _actions.length;
}

PendingAction _action(
  String id,
  PendingEndpoint endpoint, {
  Map<String, String> payloadJson = const {},
  Map<String, dynamic> payloadData = const {},
  String? photoLocalPath,
  PendingStatus status = PendingStatus.pending,
  DateTime? createdAt,
  DateTime? lastAttemptAt,
  int retryCount = 0,
  String? errorMessage,
  String idempotencyKey = 'idem-x',
}) => PendingAction(
  id: id,
  clientUuid: 'uuid-$id',
  endpoint: endpoint,
  payloadJson: payloadJson,
  payloadData: payloadData,
  photoLocalPath: photoLocalPath,
  status: status,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  lastAttemptAt: lastAttemptAt,
  retryCount: retryCount,
  errorMessage: errorMessage,
  idempotencyKey: idempotencyKey,
);