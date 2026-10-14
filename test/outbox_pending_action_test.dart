import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/outbox/pending_action.dart';

void main() {
  group('PendingAction armadaChecklistMajor', () {
    test('adalah endpoint multipart dengan path yang benar', () {
      const endpoint = PendingEndpoint.armadaChecklistMajor;

      expect(endpoint.path, '/armada/checklist-major');
      expect(endpoint.isJson, isFalse);
      expect(endpoint.isUploadMedia, isFalse);
    });

    test('encode/decode mempertahankan payload & foto checklist major', () {
      final action = PendingAction(
        id: 'a-1',
        clientUuid: 'uuid-a',
        endpoint: PendingEndpoint.armadaChecklistMajor,
        payloadJson: {
          'armada_id': 'armada-9',
          'items': jsonEncode([
            {'label': 'Ban', 'status': 'rusak_berat', 'photo_index': 0},
            {'label': 'Lampu', 'status': 'baik'},
          ]),
          'catatan': 'Ban kiri bocor',
        },
        photoLocalPaths: ['/tmp/ban.jpg'],
        createdAt: DateTime.utc(2026, 1, 1),
        idempotencyKey: 'idem-1',
      );

      final decoded = PendingAction.decode(action.encode());

      expect(decoded.endpoint, PendingEndpoint.armadaChecklistMajor);
      expect(decoded.payloadJson['armada_id'], 'armada-9');
      expect(decoded.payloadJson['catatan'], 'Ban kiri bocor');
      expect(decoded.photoLocalPaths, ['/tmp/ban.jpg']);
      expect(decoded.clientUuid, 'uuid-a');
      expect(decoded.idempotencyKey, 'idem-1');

      final items =
          jsonDecode(decoded.payloadJson['items']!) as List<dynamic>;
      expect(items, hasLength(2));
      expect(items.first['label'], 'Ban');
      expect(items.first['photo_index'], 0);
      expect(items.last['photo_index'], isNull);
    });

    test('endpoint lain tetap serial sebagai JSON body', () {
      const endpoint = PendingEndpoint.armadaRitase;
      expect(endpoint.isJson, isTrue);

      const major = PendingEndpoint.armadaChecklistMajor;
      expect(major.isJson, isFalse);
    });

    test('semua endpoint memiliki path non-kosong', () {
      for (final e in PendingEndpoint.values) {
        expect(e.path, isNotEmpty, reason: 'path untuk ${e.name}');
      }
    });
  });

  group('PendingAction endpoint foto bernama (awal/akhir & pengisian)', () {
    const awal = PendingEndpoint.armadaChecklistAwal;
    const akhir = PendingEndpoint.armadaChecklistAkhir;
    const solar = PendingEndpoint.armadaPengisianSolar;

    test('path & sifat multipart bernama', () {
      expect(awal.path, '/armada/checklist/awal');
      expect(akhir.path, '/armada/checklist/akhir');
      expect(solar.path, '/armada/pengisian-solar');

      for (final e in [awal, akhir, solar]) {
        expect(e.isNamedPhoto, isTrue, reason: e.name);
        expect(e.isJson, isFalse, reason: e.name);
        expect(e.isUploadMedia, isFalse, reason: e.name);
      }
    });

    test('encode/decode mempertahankan photoFields bernama', () {
      final action = PendingAction(
        id: 'a-2',
        clientUuid: 'uuid-b',
        endpoint: PendingEndpoint.armadaChecklistAwal,
        payloadJson: {
          'armada_id': 'armada-1',
          'stok_solar': 'setengah',
          'items[0][bagian]': 'Ban',
          'items[0][kondisi]': 'baik',
        },
        photoFields: {
          'foto_stok_solar': '/tmp/stok.jpg',
          'foto_odo_pagi': '/tmp/odo.jpg',
        },
        createdAt: DateTime.utc(2026, 1, 1),
        idempotencyKey: 'idem-2',
      );

      final decoded = PendingAction.decode(action.encode());

      expect(decoded.endpoint, PendingEndpoint.armadaChecklistAwal);
      expect(decoded.payloadJson['stok_solar'], 'setengah');
      expect(decoded.payloadJson['items[0][bagian]'], 'Ban');
      expect(decoded.photoFields['foto_stok_solar'], '/tmp/stok.jpg');
      expect(decoded.photoFields['foto_odo_pagi'], '/tmp/odo.jpg');
      expect(decoded.endpoint.isNamedPhoto, isTrue);
    });
  });
}