import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/features/armada/armada_providers.dart';
import 'package:sbps_mobile/features/armada/armada_repository.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body, {this.statusCode = 200});

  final Map<String, dynamic> body;
  final int statusCode;

  String? path;
  String? method;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    method = options.method;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

ArmadaRepository _repoWith(HttpClientAdapter adapter) {
  return ArmadaRepository(
    api: ApiClient(dio: Dio()..httpClientAdapter = adapter),
    outbox: OutboxRepository(),
    sync: OutboxSyncService(
      OutboxRepository(),
      ApiClient(dio: Dio()),
      connectivityStream: () => const Stream.empty(),
    ),
  );
}

class _RecordingSelesaiRepository extends ArmadaRepository {
  _RecordingSelesaiRepository({this.selesaiError})
      : super(
          api: ApiClient(dio: Dio()..httpClientAdapter = _JsonAdapter(const {})),
          outbox: OutboxRepository(),
          sync: OutboxSyncService(
            OutboxRepository(),
            ApiClient(dio: Dio()),
            connectivityStream: () => const Stream.empty(),
          ),
        );

  final String? selesaiError;
  final List<String> selesaiIds = [];
  final List<String> hariIniTanggalArgs = [];
  int getRitaseCalls = 0;

  @override
  Future<RitasePage> getRitase({
    int page = 1,
    int perPage = 15,
    String? tanggal,
  }) async {
    getRitaseCalls++;
    if (tanggal != null) hariIniTanggalArgs.add(tanggal);
    final sudahSelesai = selesaiIds.isNotEmpty;
    return RitasePage(
      items: [
        RitaseItem.fromJson({
          'id': 'ritase-1',
          'tanggal': tanggal ?? '2026-11-20',
          'selesai': sudahSelesai,
          'selesai_pada': sudahSelesai ? '2026-11-20T05:00:00.000Z' : null,
          'bisa_selesaikan': !sudahSelesai,
        }),
      ],
      currentPage: 1,
      lastPage: 1,
      total: 1,
    );
  }

  @override
  Future<RitaseItem> selesaikanRitase(String id) async {
    selesaiIds.add(id);
    if (selesaiError != null) throw ApiException(selesaiError!);
    return RitaseItem.fromJson({
      'id': id,
      'selesai': true,
      'selesai_pada': '2026-11-20T05:00:00.000Z',
      'bisa_selesaikan': false,
    });
  }
}

Map<String, dynamic> _selesaiPayload() => {
  'id': 'ritase-1',
  'tanggal': '2026-11-20',
  'jumlah_rit': 3,
  'status': 'disetujui',
  'selesai': true,
  'selesai_pada': '2026-11-20T05:00:00.000Z',
  'bisa_selesaikan': false,
};

void main() {
  test('fromJson memparse status selesai dan flag aksi', () {
    final item = RitaseItem.fromJson(_selesaiPayload());

    expect(item.selesai, isTrue);
    expect(item.isSelesai, isTrue);
    expect(item.selesaiPada, '2026-11-20T05:00:00.000Z');
    expect(item.bisaSelesaikan, isFalse);
  });

  test('payload lama tanpa kunci baru tetap belum selesai', () {
    final item = RitaseItem.fromJson({
      'id': 'ritase-legacy',
      'tanggal': '2026-11-20',
      'status': 'disetujui',
    });

    expect(item.isSelesai, isFalse);
    expect(item.bisaSelesaikan, isFalse);
    expect(item.selesaiPada, isNull);
  });

  test('selesaikanRitase POST ke endpoint selesai dan memetakan ritase', () async {
    final adapter = _JsonAdapter({
      'status': 'success',
      'message': 'Ritase ditandai selesai.',
      'data': _selesaiPayload(),
    });

    final item = await _repoWith(adapter).selesaikanRitase('ritase-1');

    expect(adapter.method, 'POST');
    expect(adapter.path, '/armada/ritase/ritase-1/selesai');
    expect(item.id, 'ritase-1');
    expect(item.isSelesai, isTrue);
    expect(item.selesaiPada, '2026-11-20T05:00:00.000Z');
    expect(item.bisaSelesaikan, isFalse);
  });

  test('selesaikanRitase envelope error melempar ApiException', () async {
    final adapter = _JsonAdapter({
      'status': 'error',
      'message': 'Ritase tidak ditemukan atau bukan milik Anda.',
      'data': null,
    });

    await expectLater(
      _repoWith(adapter).selesaikanRitase('ritase-1'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Ritase tidak ditemukan atau bukan milik Anda.',
        ),
      ),
    );
  });

  test('controller selesaikan delegate dan refresh list', () async {
    final repo = _RecordingSelesaiRepository();
    final container = ProviderContainer(
      overrides: [armadaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final controller = container.read(ritaseRiwayatProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    expect(repo.getRitaseCalls, 1);

    await controller.selesaikan('ritase-1');

    expect(repo.selesaiIds, ['ritase-1']);
    expect(repo.getRitaseCalls, 2);
    final state = container.read(ritaseRiwayatProvider);
    expect(state.items, hasLength(1));
    expect(state.items.single.isSelesai, isTrue);
    expect(state.error, isNull);
  });

  test('controller selesaikan menginvalidasi ritaseHariIniProvider', () async {
    final repo = _RecordingSelesaiRepository();
    final container = ProviderContainer(
      overrides: [armadaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    const tanggal = '2026-11-20';
    final hariIniSub = container.listen(
      ritaseHariIniProvider(tanggal),
      (_, __) {},
    );
    addTearDown(hariIniSub.close);

    final before = await container.read(ritaseHariIniProvider(tanggal).future);
    expect(before.items.single.isSelesai, isFalse);
    expect(before.items.single.bisaSelesaikan, isTrue);
    expect(repo.hariIniTanggalArgs, [tanggal]);

    final controller = container.read(ritaseRiwayatProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await controller.selesaikan('ritase-1');
    await Future<void>.delayed(Duration.zero);

    expect(repo.selesaiIds, ['ritase-1']);
    expect(repo.hariIniTanggalArgs, [tanggal, tanggal]);

    final after = await container.read(ritaseHariIniProvider(tanggal).future);
    expect(after.items.single.isSelesai, isTrue);
    expect(after.items.single.bisaSelesaikan, isFalse);
  });

  test('controller selesaikan mencatat ApiException ke state.error', () async {
    final repo = _RecordingSelesaiRepository(
      selesaiError: 'Gagal menandai ritase selesai.',
    );
    final container = ProviderContainer(
      overrides: [armadaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final controller = container.read(ritaseRiwayatProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await controller.selesaikan('ritase-1');

    expect(repo.selesaiIds, ['ritase-1']);
    expect(repo.getRitaseCalls, 1);
    expect(
      container.read(ritaseRiwayatProvider).error,
      'Gagal menandai ritase selesai.',
    );
  });
}
