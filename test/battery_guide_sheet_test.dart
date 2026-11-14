import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/tracking/battery_guide_sheet.dart';

void main() {
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
