import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/api_response.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';

/// AUDIT ONLINE/OFFLINE — reliability mutation.
///
/// Mengunci perbaikan pola "error saat kirim form, beberapa detik kemudian
/// item muncul di halaman sinkronisasi, lalu butuh Sync manual":
///
/// 1. `send()` tidak boleh melempar. `enqueue()` memanggilnya SETELAH item
///    tersimpan; exception yang lolos membuat UI menampilkan "gagal" padahal
///    data aman di outbox, sekaligus menghentikan sisa antrean `syncNow`.
/// 2. Reconnect & app launch memaksa flush (melewati backoff + batas retry),
///    sehingga item yang kehabisan jatah retry tidak tersandera.
/// 3. Lonjakan event konektivitas di-coalesce (single worker, §15.2/§15.4).
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('outbox_reliability');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('OutboxSyncService.send — total, tidak pernah melempar', () {
    late OutboxRepository repo;
    late _ThrowingApiClient api;
    late OutboxSyncService service;

    setUp(() async {
      api = _ThrowingApiClient();
      repo = OutboxRepository(boxName: 'rel_send');
      service = OutboxSyncService(repo, api);
      await (await Hive.openBox<String>('rel_send')).clear();
    });

    test('exception tak terduga → retryable (data tidak dibuang)', () async {
      api.error = StateError('boom');
      final result = await service.send(
        _action('r-1', PendingEndpoint.servisAjuan, payloadData: const {}),
      );

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isFalse, reason: 'jangan buang data');
      expect(result.errorMessage, isNotNull);
    });

    test('file lampiran hilang → permanen dengan pesan jelas', () async {
      api.error = const FileSystemException('missing file');
      final result = await service.send(
        _action(
          'r-2',
          PendingEndpoint.formulirSubmit,
          photoLocalPaths: const ['/tmp/hilang.jpg'],
        ),
      );

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isTrue);
      expect(result.errorMessage, contains('lampiran'));
    });

    test('enqueue TIDAK melempar saat send error tak terduga; item tetap pending', () async {
      api.error = StateError('boom');
      final action = _action(
        'r-3',
        PendingEndpoint.servisAjuan,
        payloadData: const {},
      );

      final result = await repo.enqueue(action, service.send);

      expect(result.delivered, isFalse);
      expect(result.permanentlyFailed, isFalse);
      final pending = await repo.pendingActions();
      expect(pending.map((a) => a.id), ['r-3']);
      expect(
        pending.single.status,
        PendingStatus.pending,
        reason: 'tersimpan & menunggu, bukan "Gagal dikirim"',
      );
    });

    test('send() saat aksi sama in-flight → join future (satu request, hasil asli)', () async {
      // Race `enqueue` vs worker sync: tanpa join, caller kedua menerima
      // `OutboxSendResult.queued` (delivered:false) padahal request berhasil
      // dikirim worker lain → UI lapor "gagal", item ke-churn retryable.
      final gated = _ThrowingApiClient()..gate = Completer<void>();
      final service2 = OutboxSyncService(repo, gated);
      final action = _action('race-a', PendingEndpoint.servisAjuan, payloadData: const {});

      final first = service2.send(action);
      final second = service2.send(action);
      gated.gate!.complete();

      final r1 = await first;
      final r2 = await second;

      expect(gated.jsonCalls, hasLength(1), reason: 'dua caller → SATU request nyata');
      expect(r1.delivered, isTrue);
      expect(r2.delivered, isTrue, reason: 'caller kedua dapat hasil asli, bukan queued');
    });

    test('submit saat worker syncNow mengirim aksi yang sama → enqueue delivered', () async {
      // Skema persis pola bug: item sudah dibaca worker (snapshot) ketika user
      // menekan submit. Worker & enqueue memanggil send() untuk aksi yang sama.
      final gated = _ThrowingApiClient()..gate = Completer<void>();
      final repo2 = OutboxRepository(boxName: 'rel_race');
      final service2 = OutboxSyncService(repo2, gated);
      final action = _action('race-b', PendingEndpoint.servisAjuan, payloadData: const {});

      await (await Hive.openBox<String>('rel_race')).clear();
      await (await Hive.openBox<String>('rel_race')).put(action.id, action.encode());

      final worker = service2.syncNow();
      await _waitFor(() => gated.jsonCalls.length == 1);
      final submitted = repo2.enqueue(action, service2.send);
      // Beri kesempatan enqueue mencapai send() DAN JOIN map worker. Gate
      // BELUM dibuka → worker masih in-flight, jadi enqueue tidak boleh
      // menambah request kedua.
      await _settle();
      expect(gated.jsonCalls, hasLength(1), reason: 'enqueue join worker, bukan dispatch baru');

      gated.gate!.complete();
      await worker;
      final enqueueResult = await submitted;

      expect(gated.jsonCalls, hasLength(1), reason: 'satu request nyata untuk aksi yang sama');
      expect(
        enqueueResult.delivered,
        isTrue,
        reason: 'enqueue join future worker → delivered, bukan queued',
      );
      final pending = await repo2.pendingActions();
      expect(pending, isEmpty, reason: 'aksi terhapus, tidak ada churn ke retryable');
    });

    test('satu item error tak terduga tidak menghentikan item berikutnya', () async {
      // Item pertama gagal tak terduga, item kedua harus tetap dicoba.
      final api2 = _ThrowingApiClient(failuresBeforeSuccess: 1);
      final service2 = OutboxSyncService(repo, api2);
      await _seed(
        'rel_send',
        'r-4a',
        _action(
          'r-4a',
          PendingEndpoint.servisAjuan,
          payloadData: const {},
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await _seed(
        'rel_send',
        'r-4b',
        _action(
          'r-4b',
          PendingEndpoint.servisAjuan,
          payloadData: const {},
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      );

      await service2.syncNow();

      final pending = await repo.pendingActions();
      expect(pending.map((a) => a.id), ['r-4a'], reason: 'item kedua terkirim');
    });
  });

  group('Auto-sync — launch, reconnect, coalescing', () {
    late OutboxRepository repo;
    late _ThrowingApiClient api;
    late OutboxSyncService service;
    late StreamController<List<ConnectivityResult>> connectivity;

    setUp(() async {
      api = _ThrowingApiClient();
      repo = OutboxRepository(boxName: 'rel_auto');
      connectivity = StreamController<List<ConnectivityResult>>.broadcast();
      service = OutboxSyncService(
        repo,
        api,
        connectivityStream: () => connectivity.stream,
        reconnectDebounce: const Duration(milliseconds: 10),
      );
      await (await Hive.openBox<String>('rel_auto')).clear();
    });

    tearDown(() async {
      service.dispose();
      await connectivity.close();
    });

    test('app launch force-flush item yang kehabisan jatah retry otomatis', () async {
      await _seed(
        'rel_auto',
        'l-1',
        _action(
          'l-1',
          PendingEndpoint.servisAjuan,
          payloadData: const {},
          retryCount: 5,
          lastAttemptAt: DateTime.now(),
        ),
      );

      service.start();
      await _settle();

      expect(api.jsonCalls, isNotEmpty, reason: 'backoff/batas retry dilewati');
      expect(await repo.pendingActions(), isEmpty);
    });

    test('transisi online memaksa flush item exhausted', () async {
      await _seed(
        'rel_auto',
        'c-1',
        _action(
          'c-1',
          PendingEndpoint.servisAjuan,
          payloadData: const {},
          retryCount: 5,
          lastAttemptAt: DateTime.now(),
        ),
      );

      service.handleConnectivityChange([ConnectivityResult.wifi]);
      await _settle();

      expect(await repo.pendingActions(), isEmpty);
    });

    test('lonjakan event online (OFF→ON→OFF→ON) hanya memicu satu siklus', () async {
      await _seed(
        'rel_auto',
        's-1',
        _action('s-1', PendingEndpoint.servisAjuan, payloadData: const {}),
      );

      service.handleConnectivityChange([ConnectivityResult.none]);
      service.handleConnectivityChange([ConnectivityResult.wifi]);
      service.handleConnectivityChange([ConnectivityResult.none]);
      service.handleConnectivityChange([ConnectivityResult.wifi]);
      service.handleConnectivityChange([ConnectivityResult.wifi]);
      await _settle();

      expect(api.jsonCalls, hasLength(1), reason: 'burst di-coalesce');
    });
  });

  test('force-sync saat siklus berjalan tidak hilang (coalesced follow-up)', () async {
    final slow = _SlowOutboxRepository();
    final service = OutboxSyncService(slow, _ThrowingApiClient());

    final first = service.syncNow();
    await Future<void>.delayed(Duration.zero);
    await service.syncNow(ignoreBackoff: true);
    slow.completer.complete();
    await first;
    await Future<void>.delayed(Duration.zero);

    expect(slow.calls, 2, reason: 'trigger force dijalankan setelah siklus aktif');
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

/// Menunggu [condition] benar (dengan batas waktu) — untuk mensinkronkan test
/// race agar request worker sudah terdaftar sebelum caller kedua masuk.
Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('timeout menunggu kondisi');
}

Future<void> _seed(String boxName, String key, PendingAction action) async {
  final box = await Hive.openBox<String>(boxName);
  await box.put(key, action.encode());
}

class _ThrowingApiClient extends ApiClient {
  _ThrowingApiClient({this.failuresBeforeSuccess = 0});

  Object? error;
  int failuresBeforeSuccess;

  /// Saat disetel, panggilan berikutnya (pertama) menunggu gate dibuka —
  /// untuk mensimulasikan request yang masih berjalan ketika caller kedua
  /// memanggil `send()` untuk aksi yang sama.
  Completer<void>? gate;

  final List<({String path, Map<String, dynamic>? body})> jsonCalls = [];

  Future<void> _awaitGate() async {
    if (gate == null) return;
    await gate!.future;
  }

  bool _maybeThrow() {
    if (error != null) {
      final e = error!;
      error = null;
      throw e;
    }
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw StateError('flare');
    }
    return false;
  }

  @override
  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    jsonCalls.add((path: path, body: body as Map<String, dynamic>?));
    await _awaitGate();
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
    await _awaitGate();
    _maybeThrow();
    return const ApiResponse(status: 'success', message: 'ok');
  }
}

class _SlowOutboxRepository extends OutboxRepository {
  _SlowOutboxRepository() : super(boxName: 'rel_slow');

  final completer = Completer<void>();
  int calls = 0;

  @override
  Future<List<PendingAction>> pendingActions() async {
    calls++;
    if (calls == 1) await completer.future;
    return const [];
  }
}

PendingAction _action(
  String id,
  PendingEndpoint endpoint, {
  Map<String, String> payloadJson = const {},
  Map<String, dynamic> payloadData = const {},
  String? photoLocalPath,
  List<String> photoLocalPaths = const [],
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
  photoLocalPaths: photoLocalPaths,
  status: status,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
  lastAttemptAt: lastAttemptAt,
  retryCount: retryCount,
  errorMessage: errorMessage,
  idempotencyKey: idempotencyKey,
);
