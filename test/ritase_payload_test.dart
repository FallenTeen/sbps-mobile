import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';
import 'package:sbps_mobile/features/armada/ritase_input_screen.dart';

void main() {
  group('RitaseRecord', () {
    test('toPayload mempertahankan odo_per_trip', () {
      final record = RitaseRecord(
        index: 1,
        armada: ArmadaSaya(id: 'a-1', platNomor: 'B 1234 XYZ'),
        jumlah: 3,
        satuan: 'ton',
        catatan: 'Muatan pasir',
        odoPerTrip: 12500.5,
      );

      final payload = record.toPayload();

      expect(payload['armada_id'], 'a-1');
      expect(payload['jumlah'], 3);
      expect(payload['satuan'], 'ton');
      expect(payload['catatan'], 'Muatan pasir');
      expect(payload['odo_per_trip'], 12500.5);
    });

    test('toPayload tanpa odo_per_trip tetap valid (null)', () {
      final record = RitaseRecord(
        index: 2,
        armada: ArmadaSaya(id: 'a-2', platNomor: 'D 99 XY'),
        jumlah: 1,
      );

      expect(record.toPayload()['odo_per_trip'], isNull);
      expect(record.isComplete, isTrue);
    });

    test('isComplete false bila armada/jumlah belum terisi', () {
      final incomplete = RitaseRecord(index: 3);
      expect(incomplete.isComplete, isFalse);

      final noQty = RitaseRecord(
        index: 4,
        armada: ArmadaSaya(id: 'a-4', platNomor: 'E 1 AB'),
      );
      expect(noQty.isComplete, isFalse);
    });
  });
}