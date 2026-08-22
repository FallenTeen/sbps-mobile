import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/presensi/titik_kerja_screen.dart';
import 'app_config.dart';

/// Router dengan auth guard: tanpa token → /login, sudah login → /home
/// (Fase A1.2 langkah 5). Guard client hanya lapisan UX; validasi sesungguhnya
/// tetap di backend.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresher = _ChangeSignal();
  ref.listen(authControllerProvider, (_, _) => refresher.ping());
  ref.onDispose(refresher.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresher,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggedIn = auth.value != null;
      // Sesi awal masih dimuat: jangan redirect dulu (hindari flash login).
      if (!loggedIn && auth.isLoading && !auth.hasError) return null;

      final location = state.matchedLocation;
      final onAuthScreen =
          location == '/login' || location == '/register';
      if (!loggedIn && !onAuthScreen) return '/login';
      if (loggedIn && onAuthScreen) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => AppConfig.appFlavor == 'presensi'
            ? const TitikKerjaScreen()
            : const HomeScreen(),
      ),
    ],
  );
});

class _ChangeSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
