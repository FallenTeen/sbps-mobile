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
}