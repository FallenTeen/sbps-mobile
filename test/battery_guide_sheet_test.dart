import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/tracking/battery_guide_sheet.dart';

void main() {
  group('shouldAutoShowBatteryGuide', () {
    test('tidak tampil bila sudah pernah tampil', () {
      expect(
        shouldAutoShowBatteryGuide(
          alreadyShown: true,
          presensiOpen: true,
          whileInUse: true,
          trackingRunning: false,
        ),
        isFalse,
      );
    });

    test('tidak tampil bila presensi tidak terbuka', () {
      expect(
        shouldAutoShowBatteryGuide(
          alreadyShown: false,
          presensiOpen: false,
          whileInUse: true,
          trackingRunning: false,
        ),
        isFalse,
      );
    });

    test('tampil bila presensi terbuka dan izin masih while-in-use', () {
      expect(
        shouldAutoShowBatteryGuide(
          alreadyShown: false,
          presensiOpen: true,
          whileInUse: true,
          trackingRunning: true,
        ),
        isTrue,
      );
    });

    test('tampil bila presensi terbuka dan pemantauan belum berjalan', () {
      expect(
        shouldAutoShowBatteryGuide(
          alreadyShown: false,
          presensiOpen: true,
          whileInUse: false,
          trackingRunning: false,
        ),
        isTrue,
      );
    });
  });

  test('kunci tanda tampil sekali tidak berubah', () {
    expect(kBatteryGuideShownKey, 'battery_guide_shown_v1');
  });

  test('semua merek punya 3 langkah dan tanpa teks kosong', () {
    for (final entry in kBatteryGuideEntries) {
      expect(entry.steps.length, greaterThanOrEqualTo(3));
      expect(entry.steps.length, lessThanOrEqualTo(5));
      for (final step in entry.steps) {
        expect(step.trim(), isNotEmpty);
      }
    }
  });
}
