import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'core/app_config.dart';
import 'core/app_router.dart';
import 'core/push_token_service.dart';
import 'features/presensi/presensi_providers.dart';
import 'features/tracking/tracking_providers.dart';
import 'features/version/version_gate.dart';

/// Top-level handler untuk pesan yang diterima di background/terminated.
/// Harus top-level function (bukan closure) menurut Firebase docs.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Inisialisasi Firebase — google-services.json / GoogleService-Info.plist
  // wajib ada di masing-masing flavor. Jika file tidak ada, Firebase
  // akan throw dan token dikembalikan null (graceful degradation).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('[FCM] Firebase init failed: $e — push notifications disabled');
  }

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
      ref.read(outboxSyncServiceProvider).start();
      ref.read(pendingCountProvider.notifier).reload();
      ref.read(trackingSchedulerProvider.notifier).evaluate();

      // Setup foreground FCM handler.
      try {
        FirebaseMessaging.onMessage
            .listen(firebaseMessagingForegroundHandler);
      } catch (_) {
        // Firebase tidak terinisialisasi — skip.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const title = 'SBPS';
    final theme = ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true);
    final banner = !AppConfig.isProduction;

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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: banner,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SBPS'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
