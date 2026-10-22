import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/update/shorebird_update_banner.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({
    required this.available,
    this.status = UpdateStatus.upToDate,
  });

  final bool available;
  UpdateStatus status;

  @override
  bool get isAvailable => available;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async => status;

  @override
  Future<void> update({UpdateTrack? track}) async {
    status = UpdateStatus.restartRequired;
  }

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;
}

Widget _wrap(_FakeUpdater updater) => ProviderScope(
  overrides: [shorebirdUpdaterProvider.overrideWithValue(updater)],
  child: MaterialApp(
    home: Scaffold(body: ShorebirdUpdateBanner(child: const Text('konten'))),
  ),
);

void main() {
  testWidgets('banner tidak tampil saat upToDate', (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeUpdater(available: true, status: UpdateStatus.upToDate)),
    );
    await tester.pumpAndSettle();
    expect(find.text('konten'), findsOneWidget);
    expect(find.textContaining('Pembaruan'), findsNothing);
    expect(find.textContaining('pembaruan'), findsNothing);
  });

  testWidgets('updater tidak tersedia (debug/flutter build) → kosong',
      (tester) async {
    await tester.pumpWidget(_wrap(_FakeUpdater(available: false)));
    await tester.pumpAndSettle();
    expect(find.text('konten'), findsOneWidget);
    expect(find.textContaining('aplikasi'), findsNothing);
  });

  testWidgets('update tersedia → tap unduh → instruksi buka ulang',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeUpdater(available: true, status: UpdateStatus.outdated)),
    );
    // Recheck pertama (post frame) → banner "Pembaruan tersedia".
    await tester.pump();
    expect(find.textContaining('Pembaruan tersedia'), findsOneWidget);

    await tester.tap(find.textContaining('Pembaruan tersedia'));
    await tester.pumpAndSettle();
    expect(find.textContaining('buka ulang aplikasi'), findsOneWidget);
    expect(find.textContaining('Pembaruan tersedia'), findsNothing);
  });

  testWidgets('restartRequired langsung instruksi buka ulang', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeUpdater(
          available: true,
          status: UpdateStatus.restartRequired,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('buka ulang aplikasi'), findsOneWidget);
  });
}

