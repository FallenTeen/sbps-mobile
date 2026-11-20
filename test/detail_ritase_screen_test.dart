import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/armada/detail_ritase_screen.dart';
import 'package:sbps_mobile/shared/widgets/timeline.dart';

void main() {
  test('mapping state timeline ritase', () {
    expect(timelineStatusFor('done'), TimelineStatus.done);
    expect(timelineStatusFor('current'), TimelineStatus.current);
    expect(timelineStatusFor('pending'), TimelineStatus.pending);
    expect(timelineStatusFor('skipped'), TimelineStatus.pending);
    expect(timelineStatusFor('tidak-dikenal'), TimelineStatus.pending);
  });
}
