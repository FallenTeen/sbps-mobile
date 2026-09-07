import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_picker_screen.dart';
import '../features/armada/armada_home_screen.dart';
import '../features/armada/checklist_screen.dart';
import '../features/armada/riwayat_ritase_screen.dart';
import '../features/dashboard/dashboard_home_screen.dart';
import '../features/dashboard/detail_titik_screen.dart';
import '../features/dashboard/invoice_belum_dibayar_screen.dart';
import '../features/dashboard/keuangan_screen.dart';
import '../features/dashboard/po_pending_screen.dart';
import '../features/presensi/titik_kerja_screen.dart';
import '../features/portal/portal_providers.dart';
import '../features/portal/portal_selection_screen.dart';
import '../features/produksi/mulai_sesi_screen.dart';
import '../features/produksi/progress_hari_ini_screen.dart';
import '../features/produksi/riwayat_produksi_screen.dart';
import '../features/produksi/sesi_aktif_screen.dart';
import '../features/proyek/proyek_home_screen.dart';
import '../features/proyek/role_permissions.dart';
import '../features/qc/detail_qc_screen.dart';
import '../features/qc/riwayat_qc_screen.dart';
import '../features/tracking/active_users_screen.dart';
import '../features/tracking/trail_screen.dart';
import '../features/upload/dokumentasi_screen.dart';

/// Router dengan auth guard: tanpa token → /login, sudah login → /home.
/// Portal selection ditambahkan setelah login.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresher = _ChangeSignal();
  ref.listen(authControllerProvider, (_, _) => refresher.ping());
  ref.listen(roleChoicePendingProvider, (_, _) => refresher.ping());
  ref.listen(activeRoleProvider, (_, _) => refresher.ping());
  ref.listen(selectedPortalProvider, (_, _) => refresher.ping());
  ref.onDispose(refresher.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresher,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loggedIn = auth.value != null;
      if (!loggedIn && auth.isLoading && !auth.hasError) return null;

      final location = state.matchedLocation;
      final onAuthScreen =
          location == '/login' || location == '/register';
      if (!loggedIn && !onAuthScreen) return '/login';
      if (loggedIn && onAuthScreen) return '/home';

      if (loggedIn) {
        final user = auth.value!;
        final portal = ref.read(selectedPortalProvider).value;

        // Portal selection: jika user bisa akses 2 portal tapi belum pilih.
        if (portal == null && location != '/portal') {
          final auto = autoPortal(user);
          if (auto != null) {
            // Auto-select portal, tidak perlu ke /portal.
            ref.read(selectedPortalProvider.notifier).select(auto);
          } else {
            return '/portal';
          }
        }
        if (portal != null && location == '/portal') return '/home';

        // Role choice untuk proyek portal (multi-role).
        final pickPending = ref.read(roleChoicePendingProvider);
        if (portal == AppPortal.proyek) {
          if (pickPending && location != '/pilih-role') return '/pilih-role';
          if (!pickPending && location == '/pilih-role') return '/home';

          // Guard modul produksi.
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

          // Guard modul QC.
          if (location.startsWith('/qc') &&
              !RolePermissions.canAccess(
                  ref.read(activeRoleProvider), 'qc')) {
            return '/home';
          }

          // Guard dokumentasi upload.
          if (location.startsWith('/dokumentasi') &&
              !RolePermissions.canAccess(
                  ref.read(activeRoleProvider), 'produksi')) {
            return '/home';
          }

          // Guard modul dashboard.
          if (location.startsWith('/dashboard') &&
              !RolePermissions.canAccess(
                  ref.read(activeRoleProvider), 'dashboard')) {
            return '/home';
          }

          // Guard modul armada (khusus Driver Armada).
          if (location.startsWith('/armada') &&
              !RolePermissions.canAccess(
                  ref.read(activeRoleProvider), 'armada')) {
            return '/home';
          }

          // Guard finansial: khusus Owner / Admin Keuangan.
          const financialPrefixes = <String>[
            '/dashboard/keuangan',
            '/dashboard/po-pending',
            '/dashboard/invoice',
          ];
          if (financialPrefixes.any(location.startsWith) &&
              !RolePermissions.isAdminLike(ref.read(activeRoleProvider))) {
            return '/home';
          }
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
        path: '/portal',
        builder: (context, state) => const PortalSelectionScreen(),
      ),
      GoRoute(
        path: '/pilih-role',
        builder: (context, state) => const RolePickerScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          final portal = ref.read(selectedPortalProvider).value;
          if (portal == AppPortal.proyek) return const ProyekHomeScreen();
          return const TitikKerjaScreen();
        },
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
      GoRoute(
        path: '/qc/riwayat',
        builder: (context, state) => const RiwayatQcScreen(),
      ),
      GoRoute(
        path: '/qc/detail',
        builder: (context, state) => DetailQcScreen(
          sampleId: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: '/dokumentasi',
        builder: (context, state) => const DokumentasiScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardHomeScreen(),
      ),
      GoRoute(
        path: '/dashboard/keuangan',
        builder: (context, state) => const KeuanganScreen(),
      ),
      GoRoute(
        path: '/dashboard/po-pending',
        builder: (context, state) => const PoPendingScreen(),
      ),
      GoRoute(
        path: '/dashboard/invoice',
        builder: (context, state) => const InvoiceBelumDibayarScreen(),
      ),
      GoRoute(
        path: '/dashboard/titik/:titikId',
        builder: (context, state) => DetailTitikScreen(
          titikId: state.pathParameters['titikId']!,
          nama: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/armada',
        builder: (context, state) => const ArmadaHomeScreen(),
      ),
      GoRoute(
        path: '/armada/ritase',
        builder: (context, state) => const RiwayatRitaseScreen(),
      ),
      GoRoute(
        path: '/armada/checklist',
        builder: (context, state) => const ChecklistScreen(),
      ),
    ],
  );
});

class _ChangeSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
