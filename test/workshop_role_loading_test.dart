import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/api_response.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/features/armada/models/servis_armada.dart';
import 'package:sbps_mobile/features/armada/servis_repository.dart';
import 'package:sbps_mobile/features/workshop/workshop_repository.dart';

class _Call {
  const _Call(this.path, this.query);

  final String path;
  final Map<String, dynamic>? query;
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(dio: Dio());

  final List<_Call> calls = [];
  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    final page = (query?['page'] as int?) ?? 1;
    calls.add(_Call(path, query));
    lastPath = path;
    lastQuery = query;

    final raw = <String, dynamic>{
      'current_page': page,
      'last_page': 2,
      'total': 3,
      'data': [
        for (var i = 0; i < (page == 1 ? 2 : 1); i++)
          {
            'id': 's${page}-$i',
            'armada_id': 'a$i',
            'tanggal_ajuan': '2026-09-16 08:00:00',
            'status': 'disetujui',
            'keluhan': 'Keluhan $i',
          },
      ],
    };
    final parsed = parse?.call(raw);
    return ApiResponse<T>(
      status: 'success',
      message: 'ok',
      data: parsed is T ? parsed : null,
    );
  }
}

class _StaticServisRepository extends ServisRepository {
  _StaticServisRepository._(
    this.items, {
    required ApiClient api,
    required OutboxRepository outbox,
  }) : super(
          api: api,
          outbox: outbox,
          sync: OutboxSyncService(
            outbox,
            api,
            connectivityStream: () => const Stream.empty(),
          ),
        );

  factory _StaticServisRepository(List<ServisArmada> items, ApiClient api) {
    return _StaticServisRepository._(items, api: api, outbox: OutboxRepository());
  }

  final List<ServisArmada> items;
  String? receivedStatus;
  List<String>? receivedStatuses;

  @override
  Future<List<ServisArmada>> getAllServisArmada({
    String? status,
    List<String>? statuses,
  }) async {
    receivedStatus = status;
    receivedStatuses = statuses;
    return items;
  }
}

void main() {
  ServisRepository repositoryFor(ApiClient api) {
    final outbox = OutboxRepository();
    return ServisRepository(
      api: api,
      outbox: outbox,
      sync: OutboxSyncService(
        outbox,
        api,
        connectivityStream: () => const Stream.empty(),
      ),
    );
  }

  test('daftar verifikasi eksternal memakai endpoint workshop khusus dan semua halaman', () async {
    final api = _RecordingApiClient();
    final repository = repositoryFor(api);

    final all = await repository.getServisEksternalList();

    expect(all, hasLength(3));
    expect(api.calls.map((c) => c.path), [
      '/workshop/servis-eksternal',
      '/workshop/servis-eksternal',
    ]);
    expect(api.calls.map((c) => c.query?['page']), [1, 2]);
    expect(api.calls.first.query?['per_page'], 50);
    expect(api.lastPath, '/workshop/servis-eksternal');
  });

  test('antrian servis mengambil semua halaman dan meneruskan filter status', () async {
    final api = _RecordingApiClient();
    final repository = repositoryFor(api);

    final all = await repository.getAllServisArmada(status: 'disetujui');

    expect(all, hasLength(3));
    expect(api.calls.map((c) => c.path), [
      '/servis-armada',
      '/servis-armada',
    ]);
    expect(api.calls.map((c) => c.query?['page']), [1, 2]);
    expect(api.calls.every((c) => c.query?['status'] == 'disetujui'), isTrue);
    expect(api.calls.every((c) => c.query?['per_page'] == 50), isTrue);
  });

  test('filter status jamak dikirim sebagai daftar dipisah koma', () async {
    final api = _RecordingApiClient();
    final repository = repositoryFor(api);

    await repository.getAllServisArmada(
      statuses: ['disetujui', 'dikerjakan', 'selesai'],
    );

    expect(
      api.calls.every(
        (c) => c.query?['status'] == 'disetujui,dikerjakan,selesai',
      ),
      isTrue,
    );
  });

  test('WorkshopRepository memetakan seluruh hasil servis ke antrian', () async {
    final api = _RecordingApiClient();
    final servis = _StaticServisRepository([
      ServisArmada(
        id: 'w1',
        armadaId: 'a1',
        tanggalAjuan: '2026-09-16 08:00:00',
        status: 'menunggu_sparepart',
        keluhan: 'Keluhan',
      ),
      ServisArmada(
        id: 'r1',
        armadaId: 'a2',
        tanggalAjuan: '2026-09-16 08:00:00',
        status: 'sparepart_tersedia',
        keluhan: 'Keluhan',
      ),
      ServisArmada(
        id: 'diajukan',
        armadaId: 'a3',
        tanggalAjuan: '2026-09-16 08:00:00',
        status: 'diajukan',
        keluhan: 'Keluhan',
      ),
    ], api);
    final outbox = OutboxRepository();
    final repository = WorkshopRepository(
      api: api,
      outbox: outbox,
      sync: OutboxSyncService(
        outbox,
        api,
        connectivityStream: () => const Stream.empty(),
      ),
      servis: servis,
    );

    final jobs = await repository.getAntrianServis(status: 'disetujui');

    expect(servis.receivedStatus, 'disetujui');
    expect(servis.receivedStatuses, isNull);
    expect(jobs.map((j) => j.id), ['w1', 'r1']);
    expect(jobs.map((j) => j.wireStatus), [
      'menunggu_sparepart',
      'sparepart_tersedia',
    ]);
  });

  test('WorkshopRepository tanpa filter status membatasi status di server', () async {
    final api = _RecordingApiClient();
    final servis = _StaticServisRepository([], api);
    final repository = WorkshopRepository(
      api: api,
      outbox: OutboxRepository(),
      sync: OutboxSyncService(
        OutboxRepository(),
        api,
        connectivityStream: () => const Stream.empty(),
      ),
      servis: servis,
    );

    await repository.getAntrianServis();

    expect(servis.receivedStatus, isNull);
    expect(servis.receivedStatuses, WorkshopRepository.workshopStatuses);
  });
}
