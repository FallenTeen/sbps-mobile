import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/widgets/page_transitions.dart';
import '../shared/widgets/adaptive_nav_shell.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/profile_screen.dart';
import '../features/auth/register_screen.dart';
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
import '../features/notifikasi/notifikasi_screen.dart';

/// Router dengan auth guard: tanpa token → /login, sudah login → /home.
/// Portal selection ditambahkan setelah login.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresher = _ChangeSignal();
  ref.listen(authControllerProvider, (_, _) => refresher.ping());
  ref.listen(activeRoleProvider, (_, _) => refresher.ping());
  ref.listen(selectedPortalProvider, (_, _) => refresher.ping());
  ref.onDispose(refresher.dispose);

  // Landasan Portal Proyek: berada di dalam nav shell (branch Beranda).
  const proyekLanding = '/proyek-home';
  String currentHomeFor() =>
      ref.read(selectedPortalProvider).value == AppPortal.proyek
      ? proyekLanding
      : '/home';

  StatefulShellRoute buildProyekShellRoutes() {
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        if (ref.read(selectedPortalProvider).value != AppPortal.proyek) {
          // Fallback defensif — Presensi portal tidak memakai nav shell.
          return navigationShell;
        }

        final destinations = buildNavDestinations(ref.read(activeRoleProvider));
        if (destinations.isEmpty) return navigationShell;

        final currentBranch = navigationShell.currentIndex;
        final currentDestIndex = destinations.indexWhere((d) {
          final branch = d.key == 'home' ? 0 : _proyekBranchByModule[d.key];
          return branch == currentBranch;
        });

        return AdaptiveNavShell(
          currentIndex: currentDestIndex < 0 ? 0 : currentDestIndex,
          onDestinationSelected: (destIndex) {
            final dest = destinations[destIndex];
            final branchIndex = dest.key == 'home'
                ? 0
                : _proyekBranchByModule[dest.key]!;
            navigationShell.goBranch(branchIndex, initialLocation: false);
          },
          destinations: destinations,
          child: navigationShell,
        );
      },
      branches: _proyekShellBranches(),
    );
  }

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
          return currentHomeFor();
        }

        // User Portal Proyek yang belum berada di dalam shell → arahkan ke
        // branch Beranda shell (module cards penuh tetap ada di sana).
        if (location == '/home' && currentHomeFor() != '/home') {
          return currentHomeFor();
        }

        // Guard modul produksi.
        if (location.startsWith('/produksi') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'produksi',
            )) {
          return currentHomeFor();
        }

        // Guard viewer tracking: khusus Owner / Admin Keuangan.
        if (location.startsWith('/tracking') &&
            !RolePermissions.isAdminLike(ref.read(activeRoleProvider))) {
          return currentHomeFor();
        }

        // Guard modul QC.
        if (location.startsWith('/qc') &&
            !RolePermissions.canAccess(ref.read(activeRoleProvider), 'qc')) {
          return currentHomeFor();
        }

        // Guard dokumentasi upload.
        if (location.startsWith('/dokumentasi') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'produksi',
            )) {
          return currentHomeFor();
        }

        // Guard modul dashboard.
        if (location.startsWith('/dashboard') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'dashboard',
            )) {
          return currentHomeFor();
        }

        // Guard modul armada.
        if (location.startsWith('/armada') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'armada',
            )) {
          return currentHomeFor();
        }

        // Guard modul workshop.
        if (location.startsWith('/workshop') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'workshop',
            )) {
          return currentHomeFor();
        }

        // Guard modul inventory.
        if (location.startsWith('/inventory') &&
            !RolePermissions.canAccess(
              ref.read(activeRoleProvider),
              'inventory',
            )) {
          return currentHomeFor();
        }

        // Guard finansial: khusus Owner / Admin Keuangan.
        const financialPrefixes = <String>[
          '/dashboard/keuangan',
          '/dashboard/po-pending',
          '/dashboard/invoice',
        ];
        if (financialPrefixes.any(location.startsWith) &&
            !RolePermissions.isAdminLike(ref.read(activeRoleProvider))) {
          return currentHomeFor();
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
        path: '/dokumentasi',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const DokumentasiScreen(),
        ),
      ),
      GoRoute(
        path: '/notifikasi',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const NotifikasiScreen(),
        ),
      ),
      // ── Portal Proyek: nav shell (StatefulShellRoute.indexedStack) ──
      buildProyekShellRoutes(),
    ],
  );
});

// Branch index modul di dalam shell Portal Proyek. Branch 0 = Beranda.
const _proyekBranchByModule = <String, int>{
  'produksi': 1,
  'qc': 2,
  'tracking': 3,
  'dashboard': 4,
  'keuangan': 5,
  'armada': 6,
  'kontraktor': 7,
  'workshop': 8,
  'inventory': 9,
};

List<StatefulShellBranch> _proyekShellBranches() => [
  // 0 ─ Beranda (module cards penuh)
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/proyek-home',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ProyekHomeScreen(),
        ),
      ),
    ],
  ),
  // 1 ─ Produksi
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/produksi/sesi-aktif',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const SesiAktifScreen(),
        ),
        routes: [
          GoRoute(
            path: 'mulai',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const MulaiSesiScreen(),
            ),
          ),
          GoRoute(
            path: 'riwayat',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const RiwayatProduksiScreen(),
            ),
          ),
          GoRoute(
            path: 'progress',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const ProgressHariIniScreen(),
            ),
          ),
        ],
      ),
    ],
  ),
  // 2 ─ QC
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/qc/riwayat',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: RiwayatQcScreen(
            initialSelectedId: state.uri.queryParameters['selected'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'detail/:sampleId',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: DetailQcScreen(
                sampleId: state.pathParameters['sampleId']!,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
  // 3 ─ Tracking
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/tracking/pengguna-aktif',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ActiveUsersScreen(),
        ),
        routes: [
          GoRoute(
            path: 'hari-ini/:userId',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: TrailScreen(
                userId: state.pathParameters['userId']!,
                nama: state.extra as String?,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
  // 4 ─ Dashboard Operasional
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/dashboard',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const DashboardHomeScreen(),
        ),
        routes: [
          GoRoute(
            path: 'titik/:titikId',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: DetailTitikScreen(
                titikId: state.pathParameters['titikId']!,
                nama: state.extra as String?,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
  // 5 ─ Dashboard Finansial
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/dashboard/keuangan',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const KeuanganScreen(),
        ),
        routes: [
          GoRoute(
            path: 'po-pending',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const PoPendingScreen(),
            ),
          ),
          GoRoute(
            path: 'invoice',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const InvoiceBelumDibayarScreen(),
            ),
          ),
        ],
      ),
    ],
  ),
  // 6 ─ Armada
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/armada',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ArmadaHomeScreen(),
        ),
        routes: [
          GoRoute(
            path: 'ritase',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const RiwayatRitaseScreen(),
            ),
          ),
          GoRoute(
            path: 'checklist',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const ChecklistScreen(),
            ),
          ),
          GoRoute(
            path: 'checklist-akhir',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const ChecklistScreen(isAkhir: true),
            ),
          ),
          GoRoute(
            path: 'odo-awal',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const OdoAwalScreen(),
            ),
          ),
          GoRoute(
            path: 'helper-presensi',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const HelperPresensiScreen(),
            ),
          ),
          GoRoute(
            path: 'overview',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const OverviewArmadaScreen(),
            ),
          ),
          GoRoute(
            path: 'ritase-input',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const RitaseInputScreen(),
            ),
          ),
          GoRoute(
            path: 'checklist-major',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const ChecklistMajorScreen(),
            ),
          ),
          GoRoute(
            path: 'unit-saya',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const UnitSayaHomeScreen(),
            ),
          ),
          GoRoute(
            path: 'servis',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: RiwayatServisScreen(
                initialSelectedId: state.uri.queryParameters['selected'],
              ),
            ),
            routes: [
              GoRoute(
                path: 'ajuan',
                pageBuilder: (context, state) => buildAppTransitionPage(
                  key: state.pageKey,
                  child: AjuanServisScreen(
                    initialArmadaId: state.uri.queryParameters['armadaId'],
                  ),
                ),
              ),
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => buildAppTransitionPage(
                  key: state.pageKey,
                  child: DetailServisScreen(id: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  // 7 ─ Kontraktor
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/kontraktor/proyek',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const ProyekKontrakScreen(),
        ),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: DetailProyekKontrakScreen(id: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  ),
  // 8 ─ Workshop
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/workshop',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: WorkshopQueueScreen(
            initialSelectedId: state.uri.queryParameters['selected'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'job/:id',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: WorkshopJobDetailScreen(
                jobId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
  // 9 ─ Inventory
  StatefulShellBranch(
    routes: [
      GoRoute(
        path: '/inventory',
        pageBuilder: (context, state) => buildAppTransitionPage(
          key: state.pageKey,
          child: const InventoryHomeScreen(),
        ),
        routes: [
          GoRoute(
            path: 'stok',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const InventoryStokScreen(),
            ),
          ),
          GoRoute(
            path: 'opname',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: const InventoryOpnameScreen(),
            ),
          ),
          GoRoute(
            path: 'request/:id',
            pageBuilder: (context, state) => buildAppTransitionPage(
              key: state.pageKey,
              child: InventoryRequestDetailScreen(
                requestId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
    ],
  ),
];

class _ChangeSignal extends ChangeNotifier {
  void ping() => notifyListeners();
}
