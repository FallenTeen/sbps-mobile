import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/app_config.dart';
import 'core/app_router.dart';
import 'core/push_token_service.dart';
import 'features/presensi/presensi_providers.dart';
import 'features/tracking/tracking_providers.dart';
import 'features/version/version_gate.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/notification_handler.dart';
import 'shared/widgets/sync_action_button.dart';

/// Top-level handler untuk pesan yang diterima di background/terminated.
/// Harus top-level function (bukan closure) menurut Firebase docs.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  Intl.defaultLocale = 'id_ID';
  await Hive.initFlutter();

  // Inisialisasi Firebase — google-services.json / GoogleService-Info.plist
  // wajib ada di android/app/src/main/ (unified). Jika file tidak ada,
  // Firebase akan throw dan token dikembalikan null (graceful degradation).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Crashlytics — tangkap semua error Flutter
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
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
        FirebaseMessaging.onMessage.listen(firebaseMessagingForegroundHandler);
      } catch (_) {
        // Firebase tidak terinisialisasi — skip.
      }

      // Setup notification tap handler (deep link).
      NotificationHandler.instance.initialize(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    const title = 'SBPS';
    final theme = AppTheme.lightTheme;
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
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox.shrink()),
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
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF14B8A6)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'SBPS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mobile Apps',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
