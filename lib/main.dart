import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/app_config.dart';
import 'core/app_router.dart';
import 'features/presensi/presensi_providers.dart';
import 'features/version/version_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: SbpsApp()));
}

class SbpsApp extends ConsumerStatefulWidget {
  const SbpsApp({super.key});

  @override
  ConsumerState<SbpsApp> createState() => _SbpsAppState();
}

class _SbpsAppState extends ConsumerState<SbpsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Mulai listener konektivitas + timer retry outbox.
      ref.read(outboxSyncServiceProvider).start();
      ref.read(pendingCountProvider.notifier).reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title =
        AppConfig.appFlavor == 'proyek' ? 'SBPS Proyek' : 'SBPS Presensi';
    final theme = ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true);
    final banner = !AppConfig.isProduction;

    // Force update (Fase A1.7): selagi cek berjalan tampilkan splash;
    // bila terblokir layar update menggantikan seluruh aplikasi.
    // Cek versi tidak pernah berakhir error (fail-open ke "ok").
    final gate = ref.watch(versionGateProvider);
    if (gate.isLoading) {
      return MaterialApp(
        title: title,
        theme: theme,
        debugShowCheckedModeBanner: banner,
        home: const _Splash(),
      );
    }
    final blocked = gate.value?.blocked ?? false;
    if (blocked) {
      return MaterialApp(
        title: title,
        theme: theme,
        debugShowCheckedModeBanner: banner,
        home: const UpdateRequiredScreen(),
      );
    }

    return MaterialApp.router(
      title: title,
      theme: theme,
      debugShowCheckedModeBanner: banner,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SBPS ${AppConfig.appFlavor == 'proyek' ? 'Proyek' : 'Presensi'}'),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
