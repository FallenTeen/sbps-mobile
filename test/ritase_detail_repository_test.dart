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
  Map<String, dynamic>? query;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    query = options.queryParameters;
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

class _RecordingArmadaRepository extends ArmadaRepository {
  _RecordingArmadaRepository({this.detailResult, this.pageResult})
      : super(
          api: ApiClient(dio: Dio()),
          outbox: OutboxRepository(),
          sync: OutboxSyncService(
            OutboxRepository(),
            ApiClient(dio: Dio()),
            connectivityStream: () => const Stream.empty(),
          ),
        );

  final RitaseItem? detailResult;
  final RitasePage? pageResult;
  final List<String> detailIds = [];
  final List<String?> tanggalArgs = [];

  @override
  Future<RitaseItem> getRitaseDetail(String id) async {
    detailIds.add(id);
    return detailResult!;
  }

  @override
  Future<RitasePage> getRitase({
    int page = 1,
    int perPage = 15,
    String? tanggal,
  }) async {
    tanggalArgs.add(tanggal);
    return pageResult!;
  }
}

RitaseItem _ritase() => const RitaseItem(
      id: 'ritase-1',
      tanggal: '2026-11-20',
      jumlahRit: 3,
      status: 'disetujui',
    );

void main() {
  test('getRitaseDetail memetakan data.ritase + data.timeline', () async {
    final adapter = _JsonAdapter({
      'status': 'success',
      'message': 'ok',
      'data': {
        'ritase': {
          'id': 'ritase-1',
          'tanggal': '2026-11-20',
          'jumlah_rit': 3,
          'status': 'disetujui',
          'armada_id': 'armada-1',
          'armada_plat': 'B 1234 ABC',
          'driver_nama': 'Driver Satu',
          'sumber_angka_resmi': 'driver',
          'satuan_volume': 'ritase',
        },
        'timeline': [
          {
            'key': 'diverifikasi_logistik',
            'label': 'Verifikasi logistik',
            'state': 'done',
            'badge': 'Terverifikasi',
            'at': '2026-11-20T02:15:00.000Z',
            'actor': 'Logistik Satu',
            'details': [
              {'label': 'Jumlah verifikasi', 'value': '15,5'},
            ],
          },
        ],
      },
    });

    final item = await _repoWith(adapter).getRitaseDetail('ritase-1');

    expect(adapter.path, '/armada/ritase/ritase-1');
    expect(item.id, 'ritase-1');
    expect(item.jumlahRit, 3);
    expect(item.armadaPlat, 'B 1234 ABC');
    expect(item.satuanMuatan, 'ritase');
    expect(item.timeline, hasLength(1));
    expect(item.timeline.single.key, 'diverifikasi_logistik');
    expect(item.timeline.single.state, 'done');
    expect(item.timeline.single.badge, 'Terverifikasi');
    expect(item.timeline.single.details.single.label, 'Jumlah verifikasi');
    expect(item.timeline.single.details.single.value, '15,5');
  });

  test('getRitaseDetail envelope error dengan data null melempar ApiException',
      () async {
    final adapter = _JsonAdapter({
      'status': 'error',
      'message': 'Ritase tidak ditemukan.',
      'data': null,
    });

    await expectLater(
      _repoWith(adapter).getRitaseDetail('missing'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Ritase tidak ditemukan.',
        ),
      ),
    );
  });

  test('getRitaseDetail envelope error dengan data tetap melempar ApiException',
      () async {
    final adapter = _JsonAdapter({
      'status': 'error',
      'message': 'Akses ditolak.',
      'data': {'id': 'ritase-x', 'timeline': []},
    });

    await expectLater(
      _repoWith(adapter).getRitaseDetail('ritase-x'),
      throwsA(
        isA<ApiException>().having((e) => e.message, 'message', 'Akses ditolak.'),
      ),
    );
  });

  test('getRitaseDetail fallback ke data datar bila ritase bukan Map', () async {
    final adapter = _JsonAdapter({
      'status': 'success',
      'message': 'ok',
      'data': {
        'id': 'ritase-flat',
        'jumlah_rit': 1,
        'timeline': [
          {
            'key': 'diajukan',
            'label': 'Diajukan',
            'state': 'done',
            'badge': 'Diajukan',
          },
        ],
      },
    });

    final item = await _repoWith(adapter).getRitaseDetail('ritase-flat');

    expect(item.id, 'ritase-flat');
    expect(item.timeline.single.key, 'diajukan');
  });

  test('getRitase mengirim query tanggal', () async {
    final adapter = _JsonAdapter({
      'status': 'success',
      'message': 'ok',
      'data': {'items': [], 'current_page': 1, 'last_page': 1, 'total': 0},
    });

    final page = await _repoWith(adapter).getRitase(tanggal: '2026-11-20');

    expect(adapter.path, '/armada/ritase');
    expect(adapter.query?['tanggal'], '2026-11-20');
    expect(page.items, isEmpty);
  });

  test('detailRitaseProvider meneruskan id ke getRitaseDetail', () async {
    final expected = _ritase();
    final repo = _RecordingArmadaRepository(detailResult: expected);
    final container = ProviderContainer(
      overrides: [armadaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final item = await container.read(detailRitaseProvider('ritase-1').future);

    expect(item, same(expected));
    expect(repo.detailIds, ['ritase-1']);
  });

  test('ritaseHariIniProvider meneruskan tanggal ke getRitase', () async {
    final expected = const RitasePage(
      items: [],
      currentPage: 1,
      lastPage: 1,
      total: 0,
    );
    final repo = _RecordingArmadaRepository(pageResult: expected);
    final container = ProviderContainer(
      overrides: [armadaRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final page =
        await container.read(ritaseHariIniProvider('2026-11-20').future);

    expect(page, same(expected));
    expect(repo.tanggalArgs, ['2026-11-20']);
  });
}
