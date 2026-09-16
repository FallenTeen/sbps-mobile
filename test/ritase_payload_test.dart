import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';
import 'package:sbps_mobile/features/armada/ritase_model.dart';

RitaseRecord _rec({
  required int index,
  required String armadaId,
  int jumlah = 1,
  String satuan = 'rit',
  String? catatan,
  double? odoPerTrip,
  RitaseRecordStatus status = RitaseRecordStatus.draft,
  String? clientUuid,
}) {
  final cu = clientUuid ?? 'cu-$index';
  return RitaseRecord(
    id: 'r-$index',
    index: index,
    armadaId: armadaId,
    jumlah: jumlah,
    satuan: satuan,
    catatan: catatan,
    odoPerTrip: odoPerTrip,
    createdAt: DateTime(2026, 9, 16, 8),
    status: status,
    clientUuid: cu,
    idempotencyKey: 'ik-$index',
  );
}

void main() {
  group('RitaseRecord payload (business rule tidak berubah)', () {
    test('toPayload lengkap & mempertahankan odo_per_trip', () {
      final record = _rec(
        index: 1,
        armadaId: 'a-1',
        jumlah: 3,
        satuan: 'ton',
        catatan: 'Muatan pasir',
        odoPerTrip: 12500.5,
      );

      final payload = record.toPayload();

      expect(payload['armada_id'], 'a-1');
      expect(payload['jumlah_rit'], 3);
      expect(payload['satuan_volume'], 'tonase');
      expect(payload['catatan'], 'Muatan pasir');
      expect(payload['odo_per_trip'], 12500.5);
    });

    test('tanpa odo_per_trip field tidak dikirim (tidak ada key null)', () {
      final record = _rec(index: 2, armadaId: 'a-2');

      expect(record.toPayload().containsKey('odo_per_trip'), isFalse);
      expect(record.isComplete, isTrue);
    });

    test('mapping satuan_volume tetap persis versi lama', () {
      expect(_rec(index: 1, armadaId: 'a', satuan: 'rit').satuanVolume, 'ritase');
      expect(_rec(index: 2, armadaId: 'a', satuan: 'trip').satuanVolume, 'ritase');
      expect(_rec(index: 3, armadaId: 'a', satuan: 'ton').satuanVolume, 'tonase');
      expect(_rec(index: 4, armadaId: 'a', satuan: 'm³').satuanVolume, 'm3');
      expect(_rec(index: 5, armadaId: 'a', satuan: 'kg').satuanVolume, 'ritase');
    });

    test('catatan kosong tidak dikirim sebagai payload kosong', () {
      final record = _rec(index: 6, armadaId: 'a', catatan: '   ');
      expect(record.toPayload().containsKey('catatan'), isFalse);
    });

    test('serialize/deserialize siklus utuh (status & clientUuid)', () {
      final record = _rec(
        index: 7,
        armadaId: 'a-7',
        jumlah: 4,
        satuan: 'ton',
        status: RitaseRecordStatus.queued,
        clientUuid: 'custom-7',
      );
      final restored = RitaseRecord.fromJson(record.toJson());

      expect(restored.id, record.id);
      expect(restored.index, 7);
      expect(restored.armadaId, 'a-7');
      expect(restored.jumlah, 4);
      expect(restored.satuan, 'ton');
      expect(restored.status, RitaseRecordStatus.queued);
      expect(restored.clientUuid, 'custom-7');
    });
  });

  group('summaryRitase (index Muatan Hari Ini)', () {
    test('menjawab jumlah record, unit terkait & status', () {
      final records = [
        _rec(index: 1, armadaId: 'a-1', jumlah: 5),
        _rec(index: 2, armadaId: 'a-1', jumlah: 3),
        _rec(
          index: 3,
          armadaId: 'a-2',
          jumlah: 2,
          status: RitaseRecordStatus.queued,
        ),
        _rec(
          index: 4,
          armadaId: 'a-2',
          jumlah: 1,
          status: RitaseRecordStatus.failed,
        ),
      ];

      final s = summaryRitase(records);

      expect(s.recordCount, 4);
      expect(s.unitCount, 2);
      expect(s.draftCount, 2);
      expect(s.queuedCount, 1);
      expect(s.failedCount, 1);
      expect(s.syncedCount, 0);
      expect(s.hasPending, isTrue);
      expect(s.allSynced, isFalse);
    });

    test('TIDAK menjumlah total lintas satuan berbeda (menyesatkan)', () {
      final records = [
        _rec(index: 1, armadaId: 'a', jumlah: 6, satuan: 'rit'),
        _rec(index: 2, armadaId: 'a', jumlah: 3, satuan: 'ton'),
        _rec(index: 3, armadaId: 'a', jumlah: 2, satuan: 'ton'),
      ];

      final s = summaryRitase(records);

      expect(s.bySatuan.length, 2);
      expect(s.satuanCount, 2);
      // Tidak ada satu angka total "11" yang mencampur rit dan ton.
      expect(s.satuanLabel, '6 rit · 5 ton');
      final rit = s.bySatuan.firstWhere((b) => b.satuan == 'rit');
      final ton = s.bySatuan.firstWhere((b) => b.satuan == 'ton');
      expect(rit.total, 6);
      expect(ton.total, 5);
    });

    test('allSynced hanya saat semua record terkirim', () {
      final allDone = [
        _rec(
          index: 1,
          armadaId: 'a',
          status: RitaseRecordStatus.synced,
        ),
      ];
      expect(summaryRitase(allDone).allSynced, isTrue);

      final oneQueued = [
        _rec(index: 1, armadaId: 'a', status: RitaseRecordStatus.synced),
        _rec(index: 2, armadaId: 'a', status: RitaseRecordStatus.queued),
      ];
      expect(summaryRitase(oneQueued).allSynced, isFalse);
    });
  });

  group('reconcileRecordStatus (queued != server success)', () {
    Map<String, PendingStatus> mapOf(Map<String, PendingStatus> m) => m;

    test('draft & synced tidak pernah disentuh', () {
      final draft = _rec(index: 1, armadaId: 'a');
      final synced = _rec(
        index: 2,
        armadaId: 'a',
        status: RitaseRecordStatus.synced,
      );

      expect(
        reconcileRecordStatus(draft, mapOf({'cu-1': PendingStatus.pending})),
        same(draft),
      );
      expect(
        reconcileRecordStatus(
          synced,
          mapOf({'cu-2': PendingStatus.failed}),
        ),
        same(synced),
      );
    });

    test('aksi outbox sudah hilang = diterima server → synced', () {
      final queued = _rec(
        index: 1,
        armadaId: 'a',
        status: RitaseRecordStatus.queued,
      );

      final result = reconcileRecordStatus(queued, mapOf({}));

      expect(result.status, RitaseRecordStatus.synced);
      expect(result.errorMessage, isNull);
    });

    test('aksi failed di outbox → tetap failed (pending retry)', () {
      final queued = _rec(
        index: 1,
        armadaId: 'a',
        status: RitaseRecordStatus.queued,
      );

      final result = reconcileRecordStatus(
        queued,
        mapOf({'cu-1': PendingStatus.failed}),
      );

      expect(result.status, RitaseRecordStatus.failed);
    });

    test('aksi pending/syncing di outbox → queued (belum server success)', () {
      final failed = _rec(
        index: 1,
        armadaId: 'a',
        status: RitaseRecordStatus.failed,
      );

      final result = reconcileRecordStatus(
        failed,
        mapOf({'cu-1': PendingStatus.syncing}),
      );

      expect(result.status, RitaseRecordStatus.queued);
    });

    test('record tanpa clientUuid tidak berubah status', () {
      final queued = RitaseRecord(
        id: 'x',
        index: 1,
        armadaId: 'a',
        jumlah: 1,
        satuan: 'rit',
        createdAt: DateTime(2026),
        status: RitaseRecordStatus.queued,
      );
      expect(
        reconcileRecordStatus(queued, mapOf({})),
        same(queued),
      );
    });
  });
}