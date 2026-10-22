import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/update/shorebird_update_banner.dart';
import 'package:sbps_mobile/features/version/version_gate.dart';
import 'package:sbps_mobile/features/version/version_service.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

UpdateException _fakeFail() => const UpdateException(
  message: 'gagal unduh',
  reason: UpdateFailureReason.downloadFailed,
);

class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({
    required this.available,
    this.status = UpdateStatus.upToDate,
    this.failDownload = false,
  });

  final bool available;
  UpdateStatus status;
  final bool failDownload;

  @override
  bool get isAvailable => available;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async => status;

  @override
  Future<void> update({UpdateTrack? track}) async {
    if (failDownload) throw _fakeFail();
    status = UpdateStatus.restartRequired;
  }

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;
}

class _ConstantGate extends VersionGateController {
  _ConstantGate(this.value);

  final VersionGateState value;

  @override
  Future<VersionGateState> build() async => value;
}

ProviderScope _wrap(_FakeUpdater updater, VersionGateState gate) =>
    ProviderScope(
      overrides: [
        shorebirdUpdaterProvider.overrideWithValue(updater),
        versionGateProvider.overrideWith(() => _ConstantGate(gate)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ShorebirdUpdateBanner(child: const Text('konten')),
        ),
      ),
    );

void main() {
  testWidgets('upToDate → tidak ada interupsi', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeUpdater(available: true, status: UpdateStatus.upToDate),
        VersionGateState.ok,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('konten'), findsOneWidget);
    expect(find.textContaining('Pembaruan'), findsNothing);
  });

  testWidgets('updater tidak tersedia (debug/flutter build) → kosong',
      (tester) async {
    await tester.pumpWidget(
      _wrap(_FakeUpdater(available: false), VersionGateState.ok),
    );
    await tester.pumpAndSettle();
    expect(find.text('konten'), findsOneWidget);
    expect(find.textContaining('aplikasi'), findsNothing);
  });

  testWidgets('patch outdated → unduh background → popup kuning muncul '
      'dengan changelog dari version gate', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeUpdater(available: true, status: UpdateStatus.outdated),
        const VersionGateState(
          blocked: false,
          info: AppVersionInfo(
            minVersion: '',
            latestVersion: '',
            forceUpdate: false,
            updateUrl: '',
            changelog: '- perbaikan sinkronisasi',
          ),
        ),
      ),
    );
    await tester.pump(); // refresh() mulai
    await tester.pump(); // update() selesai → popup muncul

    expect(find.text('Pembaruan telah terpasang'), findsOneWidget);
    expect(find.text('Daftar perubahan'), findsOneWidget);

    // Countdown aktif: tombol belum bisa ditutup.
    expect(find.text('Tutup dalam 3…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Tutup dalam 2…'), findsOneWidget);

    // Dismiss sebelum 3 detik gagal — prompt tetap tampil.
    await tester.tap(find.textContaining('Tutup dalam'));
    await tester.pump();
    expect(find.text('Pembaruan telah terpasang'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Setelah 3 detik, bisa ditutup dan hanya 1x per sesi.
    expect(find.text('Nanti'), findsOneWidget);
    await tester.tap(find.text('Nanti'));
    await tester.pump();
    expect(find.text('Pembaruan telah terpasang'), findsNothing);
  });

  testWidgets('restartRequired langsung popup', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeUpdater(
          available: true,
          status: UpdateStatus.restartRequired,
        ),
        VersionGateState.ok,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pembaruan telah terpasang'), findsOneWidget);
  });

  testWidgets('gagal unduh → tanpa popup, silent failure', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _FakeUpdater(
          available: true,
          status: UpdateStatus.outdated,
          failDownload: true,
        ),
        VersionGateState.ok,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Pembaruan telah terpasang'), findsNothing);
    expect(find.text('konten'), findsOneWidget);
  });
}
