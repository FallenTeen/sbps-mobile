import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/api_response.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/features/armada/models/servis_armada.dart';
import 'package:sbps_mobile/features/armada/servis_repository.dart';

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(dio: Dio());

  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    lastPath = path;
    lastQuery = query;
    return ApiResponse<T>(
      status: 'success',
      message: 'ok',
      data: (<ServisArmada>[] as T),
    );
  }
}

void main() {
  test('daftar verifikasi eksternal memakai endpoint workshop khusus', () async {
    final api = _RecordingApiClient();
    final outbox = OutboxRepository();
    final repository = ServisRepository(
      api: api,
      outbox: outbox,
      sync: OutboxSyncService(
        outbox,
        api,
        connectivityStream: () => const Stream.empty(),
      ),
    );

    await repository.getServisEksternalList();

    expect(api.lastPath, '/workshop/servis-eksternal');
    expect(api.lastQuery, isNull);
  });
}
