import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/app_config.dart';
import 'core/app_preferences.dart';
import 'core/app_router.dart';
import 'core/draft/draft_repository.dart';
import 'core/push_token_service.dart';
import 'features/armada/armada_providers.dart';
import 'features/presensi/presensi_providers.dart';
import 'features/notifikasi/notifikasi_providers.dart';
import 'features/tracking/location_buffer_service.dart';
import 'features/tracking/tracking_providers.dart';
import 'features/update/shorebird_update_banner.dart';
import 'features/version/version_gate.dart';
import 'shared/theme/app_theme.dart';
import 'shared/widgets/notification_handler.dart';
import 'shared/widgets/sync_action_button.dart';
/// Handler FCM background/terminated: wajib top-level function (ketentuan Firebase).
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

  // Firebase init: tanpa google-services.json, token push = null (degradasi halus).
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

class _SbpsAppState extends ConsumerState<SbpsApp> with WidgetsBindingObserver {
  /// Throttle refresh visual saat resume: 5 menit.
  DateTime? _lastVisualRefresh;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(outboxSyncServiceProvider).start();
      ref.read(pendingCountProvider.notifier).reload();
      ref.read(trackingSchedulerProvider.notifier).evaluate();

      // Housekeeping draft autosave: buang draft yang kedaluwarsa.
      ref.read(draftRepositoryProvider).cleanupExpired();

      // Setup foreground FCM handler.
      try {
        FirebaseMessaging.onMessage.listen((message) {
          firebaseMessagingForegroundHandler(message);
          ref.read(unreadCountProvider.notifier).reload();
        });
      } catch (_) {
        // Firebase tidak terinisialisasi — skip.
      }

      // Setup notification tap handler (deep link).
      NotificationHandler.instance.initialize(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(outboxSyncServiceProvider).syncNow(ignoreBackoff: true);
      // Cek ulang gate tracking + kirim titik yang menumpuk (timer bisa
      // di-throttle OEM di background).
      ref.read(trackingSchedulerProvider.notifier).evaluate();
      ref.read(trackingSchedulerProvider.notifier).flush();
      ref.read(shorebirdUpdateProvider.notifier).refresh();
      _refreshVisualDataOnResume();
      unawaited(_notifyTrackingInterrupted());
    }
  }

  Future<void> _notifyTrackingInterrupted() async {
    try {
      final desired = await LocationBufferService.isTrackingDesired();
      if (!desired) return;
      // Beri waktu evaluate() selesai.
      await Future<void>.delayed(const Duration(seconds: 2));
      final running = ref.read(trackingSchedulerProvider).running;
      if (running) return;
      final blocked = await LocationBufferService.isAuthBlocked();
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
          content: Text(
            blocked
                ? 'Sesi login berakhir. Buka aplikasi dan login ulang agar tracking aktif.'
                : 'Tracking GPS sempat berhenti. Buka aplikasi lebih sering agar tracking aktif.',
          ),
        ),
      );
    } catch (_) {}
  }

  /// Refresh provider baca-saja saat resume (VISUAL SAJA, tidak
  /// menyentuh outbox/auth). Hanya saat online; throttle 5 menit.
  void _refreshVisualDataOnResume() {
    final now = DateTime.now();
    final last = _lastVisualRefresh;
    if (last != null && now.difference(last) < const Duration(minutes: 5)) {
      return;
    }
    Connectivity().checkConnectivity().then((results) {
      final online = results.any(
        (r) =>
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn,
      );
      if (!online || !mounted) return;
      _lastVisualRefresh = DateTime.now();
      ref.invalidate(armadaSayaProvider);
      ref.invalidate(checklistHariIniProvider);
      ref.invalidate(helpersProvider);
      // refresh() (bukan invalidate): pertahankan item lama saat gagal.
      ref.read(ritaseRiwayatProvider.notifier).refresh();
      ref.read(unreadCountProvider.notifier).reload();
      ref.read(pendingCountProvider.notifier).reload();
    }).catchError((_) {
      // Connectivity check gagal — anggap offline, lewati refresh.
    });
  }

  @override
  Widget build(BuildContext context) {
    const title = 'SBPS';
    final theme = AppTheme.lightTheme;
    final darkTheme = AppTheme.darkTheme;
    final banner = !AppConfig.isProduction;

    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.light;

    return _App(
      title: title,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      banner: banner,
    );
  }
}

class _App extends ConsumerWidget {
  const _App({
    required this.title,
    required this.theme,
    required this.darkTheme,
    required this.themeMode,
    required this.banner,
  });

  final String title;
  final ThemeData theme;
  final ThemeData darkTheme;
  final ThemeMode? themeMode;
  final bool banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(versionGateProvider);
    if (gate.isLoading) {
      return MaterialApp(
        title: title,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: banner,
        home: _Splash(),
      );
    }

    return MaterialApp.router(
      title: title,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      builder: (context, child) => ShorebirdUpdateBanner(
        child: OfflineBanner(child: child ?? const SizedBox.shrink()),
      ),
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
      backgroundColor: context.colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.3),
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
            Text(
              'SBPS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: context.colors.textPrimary,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mobile Apps',
              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
