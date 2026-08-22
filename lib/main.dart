import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/app_config.dart';
import 'core/app_router.dart';
import 'features/presensi/presensi_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Outbox (Fase A1.4): penyimpanan aksi offline.
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
    return MaterialApp.router(
      title: AppConfig.appFlavor == 'proyek' ? 'SBPS Proyek' : 'SBPS Presensi',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: !AppConfig.isProduction,
    );
  }
}
