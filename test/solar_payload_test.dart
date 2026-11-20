import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';
import 'package:sbps_mobile/features/armada/armada_repository.dart';

class _CapturingOutbox extends OutboxRepository {
  final List<PendingAction> enqueued = [];

  @override
  Future<OutboxSendResult> enqueue(
    PendingAction action,
    Future<OutboxSendResult> Function(PendingAction) send,
  ) async {
    enqueued.add(action);
    return OutboxSendResult.queued;
  }
}

void main() {
  test('submitPengisianSolar mengirim nominal dan nota ke endpoint solar', () async {
    final outbox = _CapturingOutbox();
    final repo = ArmadaRepository(
      api: ApiClient(dio: Dio()),
      outbox: outbox,
      sync: OutboxSyncService(
        outbox,
        ApiClient(dio: Dio()),
        connectivityStream: () => const Stream.empty(),
      ),
    );

    await repo.submitPengisianSolar(
      armadaId: 'armada-1',
      odoAtauHm: 1200,
      nominalRp: 600000,
      fotoOdoPath: '/tmp/odo.jpg',
      fotoNotaPath: '/tmp/nota.jpg',
      clientUuid: 'solar-payload-test',
    );

    expect(outbox.enqueued, hasLength(1));
    final action = outbox.enqueued.single;
    expect(action.endpoint, PendingEndpoint.armadaPengisianSolar);
    expect(action.endpoint.path, '/armada/pengisian-solar');
    expect(action.payloadJson['nominal_rp'], '600000');
    expect(action.payloadJson.containsKey('liter'), isFalse);
    expect(action.payloadJson.containsKey('biaya'), isFalse);
    expect(action.photoFields['foto_odo'], '/tmp/odo.jpg');
    expect(action.photoFields['foto_nota'], '/tmp/nota.jpg');
  });
}
