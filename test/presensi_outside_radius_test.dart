import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/presensi/presensi_hari_ini_card.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';

void main() {
  group('Presensi luar radius', () {
    test('menghasilkan pesan non-blocking yang jelas', () {
      const result = CheckInResult(
        delivered: true,
        data: {'status_validasi': 'luar_radius'},
      );

      final message = presensiSubmissionMessage(result);

      expect(message, contains('Di luar area kerja'));
      expect(message, isNot(contains('Mengerti')));
    });
  });
}
