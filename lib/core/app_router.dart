import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_picker_screen.dart';
import '../features/presensi/titik_kerja_screen.dart';
import '../features/produksi/mulai_sesi_screen.dart';
import '../features/produksi/progress_hari_ini_screen.dart';
import '../features/produksi/riwayat_produksi_screen.dart';
import '../features/produksi/sesi_aktif_screen.dart';
import '../features/proyek/proyek_home_screen.dart';
import '../features/proyek/role_permissions.dart';
import '../features/tracking/active_users_screen.dart';
import '../features/tracking/trail_screen.dart';
import 'app_config.dart';

/// Router dengan auth guard: tanpa token → /login, sudah login → /home
/// (Fase A1.2 langkah 5). App 2 tambahan redirect /pilih-role saat
/// multi-role user baru login (Fase A2.2). Guard client hanya lapisan UX;
/// validasi sesungguhnya tetap di backend.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresher = _ChangeSignal();
  ref.listen(authControllerProvider, (_, _) => refresher.ping());
  ref.listen(roleChoicePendingProvider, (_, _) => refresher.ping());
  // Ganti role aktif harus memicu evaluasi ulang guard route.
  ref.listen(activeRoleProvider, (_, _) => refresher.ping());
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

      if (AppConfig.appFlavor == 'proyek') {
        final pickPending = ref.read(roleChoicePendingProvider);
        if (pickPending && location != '/pilih-role') return '/pilih-role';
        if (!pickPending && location == '/pilih-role') return '/home';

        // Guard modul produksi: hanya role dengan akses (lapisan UX).
        if (location.startsWith('/produksi') &&
            !RolePermissions.canAccess(
                ref.read(activeRoleProvider), 'produksi')) {
          return '/home';
        }

        // Guard viewer tracking: khusus Owner / Admin Keuangan.
        if (location.startsWith('/tracking') &&
            !RolePermissions.isAdminLike(ref.read(activeRoleProvider))) {
          return '/home';
        }
      }
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
        path: '/pilih-role',
        builder: (context, state) => const RolePickerScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => AppConfig.appFlavor == 'presensi'
            ? const TitikKerjaScreen()
            : const ProyekHomeScreen(),
      ),
      GoRoute(
        path: '/produksi/sesi-aktif',
        builder: (context, state) => const SesiAktifScreen(),
      ),
      GoRoute(
        path: '/produksi/mulai',
        builder: (context, state) => const MulaiSesiScreen(),
      ),
      GoRoute(
        path: '/produksi/riwayat',
        builder: (context, state) => const RiwayatProduksiScreen(),
      ),
      GoRoute(
        path: '/produksi/progress',
        builder: (context, state) => const ProgressHariIniScreen(),
      ),
      GoRoute(
        path: '/tracking/pengguna-aktif',
        builder: (context, state) => const ActiveUsersScreen(),
      ),
      GoRoute(
        path: '/tracking/hari-ini/:userId',
        builder: (context, state) => TrailScreen(
          userId: state.pathParameters['userId']!,
          nama: state.extra as String?,
        ),
      ),
    ],
  );
});

class _ChangeSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
