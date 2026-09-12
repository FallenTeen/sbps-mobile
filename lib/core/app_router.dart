import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/page_transitions.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/profile_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/role_picker_screen.dart';
import '../features/armada/ajuan_servis_screen.dart';
import '../features/armada/armada_home_screen.dart';
import '../features/armada/checklist_screen.dart';
import '../features/armada/checklist_major_screen.dart';
import '../features/armada/detail_servis_screen.dart';
import '../features/armada/helper_presensi_screen.dart';
import '../features/armada/odo_awal_screen.dart';
import '../features/armada/overview_armada_screen.dart';
import '../features/armada/riwayat_ritase_screen.dart';
import '../features/armada/riwayat_servis_screen.dart';
import '../features/armada/ritase_input_screen.dart';
import '../features/armada/unit_saya_home_screen.dart';
import '../features/workshop/workshop_queue_screen.dart';
import '../features/workshop/workshop_job_detail_screen.dart';
import '../features/inventory/inventory_home_screen.dart';
import '../features/inventory/inventory_request_detail_screen.dart';
import '../features/inventory/inventory_stok_screen.dart';
import '../features/inventory/inventory_opname_screen.dart';
import '../features/dashboard/dashboard_home_screen.dart';
import '../features/dashboard/detail_titik_screen.dart';
import '../features/dashboard/invoice_belum_dibayar_screen.dart';
import '../features/dashboard/keuangan_screen.dart';
import '../features/dashboard/po_pending_screen.dart';
import '../features/kontraktor/detail_proyek_kontrak_screen.dart';
import '../features/kontraktor/proyek_kontrak_screen.dart';
import '../features/presensi/titik_kerja_screen.dart';
import '../features/portal/portal_providers.dart';
import '../features/portal/portal_selection_screen.dart';
import '../features/portal/combined_selection_screen.dart';
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
import '../features/outbox/data_belum_terkirim_screen.dart';

/// Router dengan auth guard: tanpa token → /login, sudah login → /home.
/// Portal selection ditambahkan setelah login.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresher = _ChangeSignal();
  ref.listen(authControllerProvider, (_, _) => refresher.ping());
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
      final onAuthScreen = location == '/login' || location == '/register';
      if (!loggedIn && !onAuthScreen) return '/login';
      if (loggedIn && onAuthScreen) return '/portal';

      if (loggedIn) {
        final user = auth.value!;
        final portal = ref.read(selectedPortalProvider).value;
        final activeRole = ref.read(activeRoleProvider);

        // Portal + role selection: use combined screen
        final needsSelection =
            portal == null ||
            (portal == AppPortal.proyek && activeRole == null);

        if (needsSelection && location != '/portal') {
          return '/portal';
        }

        if (!needsSelection && location == '/portal') {
          return '/home';
        }

        // Guard modul produksi.
        if (location.startsWith('/produksi') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'produksi',
            )) {
          return '/home';
        }

        // Guard viewer tracking: khusus Owner / Admin Keuangan.
        if (location.startsWith('/tracking') &&
            !RolePermissions.isAdminLike(ref.read(activeRoleProvider))) {
          return '/home';
        }

        // Guard modul QC.
        if (location.startsWith('/qc') &&
            !RolePermissions.canAccess(ref.read(activeRoleProvider), 'qc')) {
          return '/home';
        }

        // Guard dokumentasi upload.
        if (location.startsWith('/dokumentasi') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'produksi',
            )) {
          return '/home';
        }

        // Guard modul dashboard.
        if (location.startsWith('/dashboard') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'dashboard',
            )) {
          return '/home';
        }

        // Guard modul armada.
        if (location.startsWith('/armada') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'armada',
            )) {
          return '/home';
        }

        // Guard modul workshop.
        if (location.startsWith('/workshop') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'workshop',
            )) {
          return '/home';
        }

        // Guard modul inventory.
        if (location.startsWith('/inventory') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'inventory',
            )) {
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
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/portal',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const CombinedSelectionScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) {
          final portal = ref.read(selectedPortalProvider).value;
          final child = portal == AppPortal.proyek
              ? const ProyekHomeScreen()
              : const TitikKerjaScreen();
          return buildAppTransitionPage(key: state.pageKey, child: child);
        },
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/data-belum-terkirim',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const DataBelumTerkirimScreen(),
        ),
      ),
      GoRoute(
        path: '/produksi/sesi-aktif',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const SesiAktifScreen(),
        ),
      ),
      GoRoute(
        path: '/produksi/mulai',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const MulaiSesiScreen(),
        ),
      ),
      GoRoute(
        path: '/produksi/riwayat',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const RiwayatProduksiScreen(),
        ),
      ),
      GoRoute(
        path: '/produksi/progress',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ProgressHariIniScreen(),
        ),
      ),
      GoRoute(
        path: '/tracking/pengguna-aktif',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ActiveUsersScreen(),
        ),
      ),
      GoRoute(
        path: '/tracking/hari-ini/:userId',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: TrailScreen(
            userId: state.pathParameters['userId']!,
            nama: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/qc/riwayat',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const RiwayatQcScreen(),
        ),
      ),
      GoRoute(
        path: '/qc/detail',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: DetailQcScreen(sampleId: state.extra as String? ?? ''),
        ),
      ),
      GoRoute(
        path: '/dokumentasi',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const DokumentasiScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const DashboardHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/keuangan',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const KeuanganScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/po-pending',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const PoPendingScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/invoice',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const InvoiceBelumDibayarScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/titik/:titikId',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: DetailTitikScreen(
            titikId: state.pathParameters['titikId']!,
            nama: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/armada',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ArmadaHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/armada/ritase',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const RiwayatRitaseScreen(),
        ),
      ),
      GoRoute(
        path: '/armada/checklist',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ChecklistScreen(),
        ),
      ),
      GoRoute(
        path: '/armada/checklist-akhir',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ChecklistScreen(isAkhir: true),
        ),
      ),
      GoRoute(
        path: '/armada/odo-awal',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const OdoAwalScreen(),
        ),
      ),
      GoRoute(
        path: '/armada/helper-presensi',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const HelperPresensiScreen(),
        ),
      ),
      GoRoute(
        path: '/armada/servis',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const RiwayatServisScreen(),
        ),
      ),
      GoRoute(
        path: '/armada/servis/ajuan',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: AjuanServisScreen(
            initialArmadaId: state.uri.queryParameters['armadaId'],
          ),
        ),
      ),
      GoRoute(
        path: '/armada/servis/:id',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: DetailServisScreen(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/armada/overview',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const OverviewArmadaScreen(),
        ),
      ),
      GoRoute(
        path: '/armada/ritase-input',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const RitaseInputScreen(),
        ),
      ),
      // Legacy workshop-todo route retired in Fase 2 - migrated to proper workshop module
      GoRoute(
        path: '/armada/checklist-major',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ChecklistMajorScreen(),
        ),
      ),
      GoRoute(
        path: '/kontraktor/proyek',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ProyekKontrakScreen(),
        ),
      ),
      GoRoute(
        path: '/kontraktor/proyek/:id',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: DetailProyekKontrakScreen(id: state.pathParameters['id']!),
        ),
      ),
      // ── Unit Saya (Driver Armada workflow) ──
      GoRoute(
        path: '/armada/unit-saya',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const UnitSayaHomeScreen(),
        ),
      ),
      // ── Workshop ──
      GoRoute(
        path: '/workshop',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const WorkshopQueueScreen(),
        ),
      ),
      GoRoute(
        path: '/workshop/job/:id',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: WorkshopJobDetailScreen(jobId: state.pathParameters['id']!),
        ),
      ),
      // ── Inventory ──
      GoRoute(
        path: '/inventory',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const InventoryHomeScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory/stok',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const InventoryStokScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory/opname',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const InventoryOpnameScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory/request/:id',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: InventoryRequestDetailScreen(
            requestId: state.pathParameters['id']!,
          ),
        ),
      ),
    ],
  );
});

class _ChangeSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
