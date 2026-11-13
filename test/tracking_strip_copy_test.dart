import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/presensi/titik_kerja_screen.dart';

void main() {
  group('trackingStripDetail', () {
    test('null/empty tidak menampilkan detail', () {
      expect(trackingStripDetail(null), isNull);
      expect(trackingStripDetail(''), isNull);
    });

    test('pesan generik stop disembunyikan', () {
      expect(trackingStripDetail('Tracking tidak aktif.'), isNull);
    });

    test('pesan bermakna diteruskan apa adanya', () {
      expect(
        trackingStripDetail('Izin lokasi belakang belum aktif.'),
        'Izin lokasi belakang belum aktif.',
      );
    });
  });
}
