import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';
import 'package:sbps_mobile/features/proyek/pending_summary_provider.dart';

void main() {
  group('PendingSummary mapping', () {
    test('workshopCount menggunakan workshopMulai/workshopSelesai, bukan armadaChecklist',
        () async {
      final repo = _FakeOutboxRepository([
        _action(PendingEndpoint.workshopMulai),
        _action(PendingEndpoint.workshopSelesai),
        _action(PendingEndpoint.armadaChecklist), // harus DIABAIKAN
      ]);
      final ps = PendingSummary(repository: repo);
      final counts = await ps.getSummary('Workshop');

      expect(counts.workshop, 2);
    });

    test('armadaCount mencakup armadaRitase dan armadaChecklistMajor', () async {
      final repo = _FakeOutboxRepository([
        _action(PendingEndpoint.armadaRitase),
        _action(PendingEndpoint.armadaChecklistMajor),
        _action(PendingEndpoint.armadaOdoAwal),
      ]);
      final ps = PendingSummary(repository: repo);
      final counts = await ps.getSummary('Driver Armada');

      expect(counts.armada, 3);
    });

    test('inventoryCount mencakup inventoryOpname', () async {
      final repo = _FakeOutboxRepository([
        _action(PendingEndpoint.inventoryOpname),
      ]);
      final ps = PendingSummary(repository: repo);
      final counts = await ps.getSummary('Owner');

      expect(counts.inventory, 1);
    });

    test('formulirCount mencakup formulirSubmit', () async {
      final repo = _FakeOutboxRepository([
        _action(PendingEndpoint.formulirSubmit),
      ]);
      final ps = PendingSummary(repository: repo);
      final counts = await ps.getSummary('Owner');

      expect(counts.formulir, 1);
    });

    test('presensiCount mencakup presensiCheckIn dan presensiCheckOut', () async {
      final repo = _FakeOutboxRepository([
        _action(PendingEndpoint.presensiCheckIn),
        _action(PendingEndpoint.presensiCheckOut),
      ]);
      final ps = PendingSummary(repository: repo);
      final counts = await ps.getSummary('Driver Armada');

      expect(counts.presensi, 2);
    });

    test('role yang tidak memiliki akses menghasilkan 0', () async {
      final repo = _FakeOutboxRepository([
        _action(PendingEndpoint.armadaRitase),
      ]);
      final ps = PendingSummary(repository: repo);
      final counts = await ps.getSummary('Workshop');

      expect(counts.armada, 0);
    });
  });
}

class _FakeOutboxRepository extends OutboxRepository {
  _FakeOutboxRepository(List<PendingAction> actions) : _actions = actions;

  final List<PendingAction> _actions;

  @override
  Future<List<PendingAction>> pendingActions() async => List.of(_actions);
}

PendingAction _action(PendingEndpoint endpoint) => PendingAction(
      id: 'id-${endpoint.name}',
      clientUuid: 'uuid-${endpoint.name}',
      endpoint: endpoint,
      payloadJson: const {},
      createdAt: DateTime.now(),
      idempotencyKey: 'idem-${endpoint.name}',
    );