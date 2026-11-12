import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/core/outbox/outbox_repository.dart';
import 'package:sbps_mobile/core/outbox/outbox_sync_service.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';
import 'package:sbps_mobile/features/armada/armada_repository.dart';
import 'package:sbps_mobile/features/armada/checklist_model.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Menangkap PendingAction yang masuk outbox tanpa Hive/network.
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

OutboxSyncService _sync(OutboxRepository repo) => OutboxSyncService(
  repo,
  ApiClient(dio: Dio()),
  connectivityStream: () => const Stream.empty(),
);

ArmadaRepository _repo(OutboxRepository outbox) => ArmadaRepository(
  api: ApiClient(dio: Dio()),
  outbox: outbox,
  sync: _sync(outbox),
);

void main() {
  group('checklistBagianGap (validasi dokumentasi submit)', () {
    test('perlu perhatian tanpa foto diblokir (foto kini wajib)', () {
      expect(
        checklistBagianGap(
          ChecklistItemLevel.perluPerhatian,
          'Suara mesin kasar',
          null,
        ),
        ChecklistDocGap.perluPerhatianTanpaFoto,
      );
      expect(
        checklistBagianGap(
          ChecklistItemLevel.perluPerhatian,
          'Suara mesin kasar',
          '',
        ),
        ChecklistDocGap.perluPerhatianTanpaFoto,
      );
    });

    test('perlu perhatian dengan foto + catatan lolos', () {
      expect(
        checklistBagianGap(
          ChecklistItemLevel.perluPerhatian,
          'Suara mesin kasar',
          '/tmp/foto-lampu.jpg',
        ),
        ChecklistDocGap.none,
      );
    });

    test('perlu perhatian dengan foto tapi tanpa catatan tetap diblokir', () {
      expect(
        checklistBagianGap(
          ChecklistItemLevel.perluPerhatian,
          '   ',
          '/tmp/foto-lampu.jpg',
        ),
        ChecklistDocGap.catatanKosong,
      );
    });

    test('rusak tanpa foto diblokir (aturan lama tetap)', () {
      expect(
        checklistBagianGap(ChecklistItemLevel.rusak, 'Rem tidak pakem', null),
        ChecklistDocGap.rusakTanpaFoto,
      );
    });

    test('rusak dengan catatan + foto lolos', () {
      expect(
        checklistBagianGap(
          ChecklistItemLevel.rusak,
          'Rem tidak pakem',
          '/tmp/foto-rem.jpg',
        ),
        ChecklistDocGap.none,
      );
    });

    test('baik tidak menuntut catatan/foto walau dokumentasi lama ada', () {
      expect(
        checklistBagianGap(
          ChecklistItemLevel.baik,
          'catatan lama',
          '/tmp/foto-lama.jpg',
        ),
        ChecklistDocGap.none,
      );
    });

    test('level null = belum diperiksa', () {
      expect(
        checklistBagianGap(null, '', null),
        ChecklistDocGap.belumDiperiksa,
      );
    });
  });

  group('checklistItemPayload (payload submit)', () {
    test('item baik hanya bagian + kondisi walau catatan/foto lama ada', () {
      final payload = checklistItemPayload(
        bagian: 'Ban',
        level: ChecklistItemLevel.baik,
        catatan: 'catatan lama',
        fotoPath: '/tmp/foto-lama.jpg',
      );

      expect(payload.keys.toSet(), {'bagian', 'kondisi'});
      expect(payload['bagian'], 'Ban');
      expect(payload['kondisi'], 'baik');
    });

    test('item rusak mengirim kondisi + catatan + foto', () {
      final payload = checklistItemPayload(
        bagian: 'Rem',
        level: ChecklistItemLevel.rusak,
        catatan: ' Rem tidak pakem ',
        fotoPath: '/tmp/foto-rem.jpg',
      );

      expect(payload['kondisi'], 'rusak');
      expect(payload['catatan'], 'Rem tidak pakem');
      expect(payload['foto'], '/tmp/foto-rem.jpg');
    });

    test('item perlu perhatian mengirim kondisi + catatan + foto', () {
      final payload = checklistItemPayload(
        bagian: 'Lampu',
        level: ChecklistItemLevel.perluPerhatian,
        catatan: 'Lampu senja mati',
        fotoPath: '/tmp/foto-lampu.jpg',
      );

      expect(payload['kondisi'], 'perlu_perhatian');
      expect(payload['catatan'], 'Lampu senja mati');
      expect(payload['foto'], '/tmp/foto-lampu.jpg');
    });
  });

  group('nextExpandedIndexAfterLevel (perilaku accordion)', () {
    test('perlu perhatian: accordion tetap di item yang sama', () {
      final result = nextExpandedIndexAfterLevel(
        index: 1,
        level: ChecklistItemLevel.perluPerhatian,
        levels: const [ChecklistItemLevel.baik, null, null],
      );
      expect(result, 1);
    });

    test('rusak: accordion tetap di item yang sama', () {
      final result = nextExpandedIndexAfterLevel(
        index: 2,
        level: ChecklistItemLevel.rusak,
        levels: const [null, ChecklistItemLevel.baik, null],
      );
      expect(result, 2);
    });

    test('baik: lanjut ke bagian berikutnya yang belum diisi', () {
      final result = nextExpandedIndexAfterLevel(
        index: 0,
        level: ChecklistItemLevel.baik,
        levels: const [ChecklistItemLevel.baik, null, null],
      );
      expect(result, 1);
    });

    test('baik saat semua sudah diisi: accordion menutup (null)', () {
      final result = nextExpandedIndexAfterLevel(
        index: 2,
        level: ChecklistItemLevel.baik,
        levels: const [
          ChecklistItemLevel.baik,
          ChecklistItemLevel.baik,
          ChecklistItemLevel.baik,
        ],
      );
      expect(result, isNull);
    });
  });

  group('ArmadaRepository.checklistItemFields (multipart)', () {
    test('foto item bermasalah jadi photoFields, bukan string field', () {
      final (fields, photos) = ArmadaRepository.checklistItemFields([
        {
          'bagian': 'Rem',
          'kondisi': 'rusak',
          'catatan': 'Rem tidak pakem',
          'foto': '/tmp/foto-rem.jpg',
        },
      ]);

      expect(fields['items[0][bagian]'], 'Rem');
      expect(fields['items[0][kondisi]'], 'rusak');
      expect(fields['items[0][catatan]'], 'Rem tidak pakem');
      expect(
        photos['items[0][foto]'],
        '/tmp/foto-rem.jpg',
        reason: 'foto item dikirim sebagai file multipart items[i][foto]',
      );
      expect(
        fields.containsKey('items[0][foto]'),
        isFalse,
        reason: 'foto TIDAK dikirim sebagai string field',
      );
    });

    test('item baik tidak membawa catatan/foto ke payload', () {
      final (fields, photos) = ArmadaRepository.checklistItemFields([
        {
          'bagian': 'Ban',
          'kondisi': 'baik',
          'catatan': 'catatan lama',
          'foto': '/tmp/foto-lama.jpg',
        },
      ]);

      expect(fields.containsKey('items[0][catatan]'), isFalse);
      expect(fields.containsKey('items[0][foto]'), isFalse);
      expect(photos, isEmpty);
    });

    test('tanpa kondisi dianggap baik (fallback lama tetap)', () {
      final (fields, photos) = ArmadaRepository.checklistItemFields([
        {'bagian': 'Oli mesin', 'foto': '/tmp/foto-oli.jpg'},
      ]);

      expect(fields['items[0][kondisi]'], 'baik');
      expect(photos, isEmpty);
      expect(fields.containsKey('items[0][foto]'), isFalse);
    });
  });

  group('submitChecklistAwal (wiring photoFields item)', () {
    test('foto item bermasalah masuk photoFields, payloadJson bebas foto', () async {
      final outbox = _CapturingOutbox();
      final repo = _repo(outbox);

      final delivered = await repo.submitChecklistAwal(
        armadaId: 'a-1',
        items: [
          {
            'bagian': 'Ban',
            'kondisi': 'baik',
            'catatan': 'catatan lama',
            'foto': '/tmp/foto-lama.jpg',
          },
          {
            'bagian': 'Rem',
            'kondisi': 'rusak',
            'catatan': 'Rem tidak pakem',
            'foto': '/tmp/foto-rem.jpg',
          },
        ],
        stokSolar: 'penuh',
        odoPagi: 1200,
        fotoStokSolarPath: '/tmp/foto-stok.jpg',
        fotoOdoPagiPath: '/tmp/foto-odo.jpg',
      );

      expect(delivered, isFalse, reason: 'fake outbox mengembalikan queued');
      expect(outbox.enqueued, hasLength(1));

      final action = outbox.enqueued.single;
      expect(action.endpoint, PendingEndpoint.armadaChecklistAwal);

      // Foto item bermasalah jadi FILE multipart items[1][foto].
      expect(action.photoFields['items[1][foto]'], '/tmp/foto-rem.jpg');
      expect(action.photoFields['foto_stok_solar'], '/tmp/foto-stok.jpg');
      expect(action.photoFields['foto_odo_pagi'], '/tmp/foto-odo.jpg');

      // Foto item baik tidak ikut; payloadJson tidak punya string foto item.
      expect(action.photoFields.containsKey('items[0][foto]'), isFalse);
      expect(
        action.payloadJson.keys.any((k) => k.contains('[foto]')),
        isFalse,
      );

      // Field string item tetap utuh (bagian/kondisi/catatan).
      expect(action.payloadJson['items[0][bagian]'], 'Ban');
      expect(action.payloadJson['items[0][kondisi]'], 'baik');
      expect(action.payloadJson['items[1][kondisi]'], 'rusak');
      expect(action.payloadJson['items[1][catatan]'], 'Rem tidak pakem');
      expect(action.payloadJson.containsKey('items[0][catatan]'), isFalse);

      // client_uuid & idempotency tetap diisi.
      expect(action.clientUuid, isNotEmpty);
      expect(action.idempotencyKey, isNotEmpty);
    });

    test('submitChecklistAkhir memakai aturan foto item yang sama', () async {
      final outbox = _CapturingOutbox();
      final repo = _repo(outbox);

      await repo.submitChecklistAkhir(
        armadaId: 'a-2',
        items: [
          {
            'bagian': 'Lampu',
            'kondisi': 'perlu_perhatian',
            'catatan': 'Lampu senja mati',
            'foto': '/tmp/foto-lampu.jpg',
          },
        ],
        stokSolar: 'setengah',
        odoAkhir: 1300,
      );

      final action = outbox.enqueued.single;
      expect(action.endpoint, PendingEndpoint.armadaChecklistAkhir);
      expect(action.photoFields['items[0][foto]'], '/tmp/foto-lampu.jpg');
      expect(action.photoFields.containsKey('foto_odo_akhir'), isFalse);
      expect(action.payloadJson['items[0][kondisi]'], 'perlu_perhatian');
      expect(action.payloadJson.containsKey('items[0][foto]'), isFalse);
    });
  });
}
