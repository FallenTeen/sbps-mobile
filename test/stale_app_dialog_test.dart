import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/update/stale_app_dialog.dart';
import 'package:sbps_mobile/features/version/version_gate.dart';
import 'package:sbps_mobile/features/version/version_service.dart';
import 'package:sbps_mobile/shared/widgets/portal_switch_button.dart';

AppVersionInfo _info() => const AppVersionInfo(
  minVersion: '2.0.0',
  latestVersion: '2.0.0',
  forceUpdate: true,
  updateUrl: 'https://staging.sbpscorp.com/apk/sbps.apk',
  changelog: null,
);

class _ConstantGate extends VersionGateController {
  _ConstantGate(this.value);

  final VersionGateState value;

  @override
  Future<VersionGateState> build() async => value;
}

ProviderScope _wrap(VersionGateState gate, Widget child) => ProviderScope(
  overrides: [versionGateProvider.overrideWith(() => _ConstantGate(gate))],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('app kadaluwarsa → modal merah dengan tombol unduh',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        VersionGateState(blocked: true, info: _info()),
        StaleAppGate(child: const Text('login')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aplikasi Kadaluwarsa'), findsOneWidget);
    expect(find.textContaining('minimal 2.0.0'), findsOneWidget);
    expect(find.text('Unduh Aplikasi'), findsOneWidget);

    // Tutup dengan "Nanti" — state user tidak hilang.
    await tester.tap(find.text('Nanti'));
    await tester.pumpAndSettle();
    expect(find.text('Aplikasi Kadaluwarsa'), findsNothing);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('gate ok → tanpa modal', (tester) async {
    await tester.pumpWidget(
      _wrap(VersionGateState.ok, StaleAppGate(child: const Text('login'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aplikasi Kadaluwarsa'), findsNothing);
  });

  testWidgets('label "Aplikasi Kadaluwarsa" di samping tombol portal → '
      'klik membuka modal', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VersionGateState(blocked: true, info: _info()),
        Scaffold(
          appBar: AppBar(actions: const [PortalSwitchButton()]),
          body: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aplikasi Kadaluwarsa'), findsOneWidget);
    await tester.tap(find.text('Aplikasi Kadaluwarsa'));
    await tester.pumpAndSettle();
    expect(find.text('Unduh Aplikasi'), findsOneWidget);
  });

  testWidgets('gate ok → label portal tidak tampil', (tester) async {
    await tester.pumpWidget(
      _wrap(
        VersionGateState.ok,
        Scaffold(
          appBar: AppBar(actions: const [PortalSwitchButton()]),
          body: const Text('home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aplikasi Kadaluwarsa'), findsNothing);
  });
}
