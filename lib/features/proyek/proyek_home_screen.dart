import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/theme/touch_targets.dart';
import '../../shared/widgets/adaptive_grid.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_screen_frame.dart';
import '../../shared/widgets/illustrated_empty_state.dart';
import '../../shared/widgets/app_top_bar_actions.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/global_search_sheet.dart';
import '../../shared/widgets/pinned_modules_row.dart';
import '../../shared/widgets/section_header.dart';
import '../auth/auth_providers.dart';
import '../tracking/tracking_providers.dart';
import 'home_quick_actions.dart';
import 'role_permissions.dart';
import 'pending_summary_provider.dart';
import '../../shared/utils/module_routes.dart';

/// Rute tujuan setiap kartu modul di Beranda Proyek.
/// Menjadi satu-satunya sumber keputusan navigasi supaya modul baru tidak
/// terjebak di fallback "belum tersedia".
String? proyekModuleRoute(String moduleKey) => moduleRouteFor(moduleKey);

class ProyekHomeScreen extends ConsumerWidget {
  const ProyekHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final role = ref.watch(activeRoleProvider);
    final allowed = kProyekModules
        .where((m) => RolePermissions.canAccess(role, m.key))
        .where((m) => m.key != 'tracking' || RolePermissions.isAdminLike(role))
        .toList();

    final searchModules = <SearchableModule>[
      SearchableModule(
        name: 'Modul',
        items: allowed
            .map(
              (m) => SearchResult(
                title: m.label,
                subtitle: m.key,
                icon: m.icon,
                route: '/proyek',
              ),
            )
            .toList(),
      ),
    ];

    void openSearchResult(SearchResult result) {
      final route = moduleRouteFor(result.subtitle);
      if (route != null) {
        context.push(route);
      }
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: AppScreenFrame(
        title: 'Beranda',
        maxWidth: AppBreakpoints.maxContentWidth - (AppSpacing.md * 2),
        actions: const [AppTopBarActions(showNotification: false)],
        search: _HeaderSearchField(
          onTap: () => showGlobalSearchSheet(
            context,
            modules: searchModules,
            onSelected: openSearchResult,
          ),
        ),
        body: role == null
            ? const AppEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Peran aktif tidak tersedia',
                subtitle: 'Peran aktif tidak tersedia untuk App Proyek.',
                illustrationVariant: EmptyStateVariant.noPermission,
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  // Greeting header
                  _GreetingHeader(user: user, role: role),
                  const SizedBox(height: 20),

                  PinnedModulesRow(
                    allowedModules: RolePermissions.modulesFor(role),
                  ),
                  const SizedBox(height: 16),

                  if (role == 'Mandor Titik') ...[
                    const _TrackingStatusCard(),
                    const SizedBox(height: 16),
                  ],

                  // Pekerjaan Menunggu Anda card
                  _PendingWorkCard(role: role),
                  const SizedBox(height: 16),

                  // Quick Actions per role (Fase 2)
                  _QuickActions(role: role),
                  SizedBox(height: 16),

                  // Section: Modul
                  const SectionHeader(
                    title: 'Modul',
                    leadingIcon: Icons.grid_view_rounded,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),

                  AdaptiveGrid(
                    compactColumns: 1,
                    mediumColumns: 2,
                    expandedColumns: 2,
                    spacing: 10,
                    children: [
                      for (var i = 0; i < allowed.length; i++)
                        StaggeredEntrance(
                          index: i,
                          child: _ModuleCard(module: allowed[i]),
                        ),
                    ],
                  ),
                ],
              ),
        ),
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: context.colors.border),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: TextField(
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: 'Cari modul...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: context.colors.surfaceVariant,
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.user, required this.role});

  final dynamic user;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Selamat Pagi'
        : hour < 15
        ? 'Selamat Siang'
        : 'Selamat Sore';

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _iconForRole(role ?? ''),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
                Text(
                  user?.name ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends ConsumerWidget {
  const _ModuleCard({required this.module});

  final ProyekModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigate(context, ref),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    module.icon,
                    color: context.colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleFor(module.key),
                        style: TextStyle(
                          color: context.colors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pending badge
                _PendingBadge(moduleKey: module.key, role: role),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, WidgetRef ref) {
    final role = ref.read(activeRoleProvider);
    final isPrimaryTugas = module.key == tugasModuleFor(role);

    void open(String route) {
      if (isPrimaryTugas) {
        context.go(route);
      } else {
        context.push(route);
      }
    }

    final route = proyekModuleRoute(module.key);
    if (route != null) {
      open(route);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${module.label} belum tersedia')));
  }

  String _subtitleFor(String key) => switch (key) {
    'produksi' => 'Sesi aktif, mulai, riwayat, progress, QC',
    'qc' => 'Antrian pemeriksaan, catat slump & uji tekan',
    'tracking' => 'User aktif & jejak lokasi',
    'dashboard' => 'Ringkasan titik & operasional',
    'keuangan' => 'Chart keuangan, PO, invoice',
    'armada' => 'Kendaraan, ritase & checklist harian',
    'kontraktor' => 'Proyek kontrak, progress, invoice & chat',
    'workshop' => 'Antrian servis, checklist pengerjaan & sparepart',
    'inventory' => 'Stok barang, request sparepart & opname',
    'logistik' => 'Verifikasi ritase & timbang',
    'security' => 'Buku tamu, checklist & laporan darurat',
    _ => 'Menyusul di fase berikutnya',
  };
}

IconData _iconForRole(String role) => switch (role) {
  'Mandor Titik' => Icons.engineering_rounded,
  'Kontraktor' => Icons.business_center_rounded,
  'Admin Keuangan' => Icons.account_balance_wallet_rounded,
  'Owner' => Icons.supervisor_account_rounded,
  'Driver Armada' ||
  'Driver Standby' ||
  'Driver Kondisional' => Icons.local_shipping_rounded,
  _ => Icons.badge_rounded,
};

class _TrackingStatusCard extends ConsumerWidget {
  const _TrackingStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(trackingSchedulerProvider);

    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.running
              ? context.colors.success.withValues(alpha: 0.3)
              : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: status.running
                  ? context.colors.success.withValues(alpha: 0.1)
                  : context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              status.running
                  ? Icons.location_on_rounded
                  : Icons.location_off_rounded,
              color: status.running
                  ? context.colors.success
                  : context.colors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.running ? 'Lokasi Dipantau' : 'Tracking Tidak Aktif',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (status.message != null)
                  Text(
                    status.message!,
                    style: TextStyle(color: context.colors.error, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (status.pendingPoints > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${status.pendingPoints} antre',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// â”€â”€ No Active Role â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

// â”€â”€ Pekerjaan Menunggu Anda Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PendingWorkCard extends ConsumerWidget {
  const _PendingWorkCard({required this.role});

  final String? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSummary = ref.watch(pendingSummaryProvider);

    return FutureBuilder<ModulePendingCounts>(
      future: pendingSummary.getSummary(role ?? ''),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const ModulePendingCounts();

        if (!counts.hasPending) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.colors.warning,
                Color.lerp(context.colors.warning, Colors.black, 0.3)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: context.colors.warning.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.pending_actions,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pekerjaan Menunggu Anda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${counts.total} menunggu',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _PendingItemsList(counts: counts),
            ],
          ),
        );
      },
    );
  }
}

class _PendingItemsList extends StatelessWidget {
  const _PendingItemsList({required this.counts});

  final ModulePendingCounts counts;

  @override
  Widget build(BuildContext context) {
    final items = <_PendingItem>[];

    if (counts.armada > 0) {
      items.add(_PendingItem(label: 'Armada', count: counts.armada));
    }
    if (counts.produksi > 0) {
      items.add(_PendingItem(label: 'Produksi', count: counts.produksi));
    }
    if (counts.qc > 0) {
      items.add(_PendingItem(label: 'QC', count: counts.qc));
    }
    if (counts.workshop > 0) {
      items.add(_PendingItem(label: 'Workshop', count: counts.workshop));
    }
    if (counts.inventory > 0) {
      items.add(_PendingItem(label: 'Inventory', count: counts.inventory));
    }
    if (counts.formulir > 0) {
      items.add(_PendingItem(label: 'Formulir', count: counts.formulir));
    }
    if (counts.upload > 0) {
      items.add(_PendingItem(label: 'Unggah', count: counts.upload));
    }
    if (counts.presensi > 0) {
      items.add(_PendingItem(label: 'Presensi', count: counts.presensi));
    }

    return Wrap(spacing: 8, runSpacing: 8, children: items);
  }
}

class _PendingItem extends StatelessWidget {
  const _PendingItem({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PendingBadge extends ConsumerWidget {
  const _PendingBadge({required this.moduleKey, required this.role});

  final String moduleKey;
  final String? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSummary = ref.watch(pendingSummaryProvider);

    return FutureBuilder<ModulePendingCounts>(
      future: pendingSummary.getSummary(role ?? ''),
      builder: (context, snapshot) {
        final counts = snapshot.data ?? const ModulePendingCounts();
        final count = _getCountForModule(counts, moduleKey);

        if (count == 0) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.warning,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }

  int _getCountForModule(ModulePendingCounts counts, String moduleKey) {
    switch (moduleKey) {
      case 'armada':
        return counts.armada;
      case 'produksi':
        return counts.produksi;
      case 'qc':
        return counts.qc;
      case 'workshop':
        return counts.workshop;
      case 'inventory':
        return counts.inventory;
      case 'formulir':
        return counts.formulir;
      case 'upload':
        return counts.upload;
      case 'presensi':
        return counts.presensi;
      default:
        return 0;
    }
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final actions = homeQuickActionKeysForRole(role).map((key) {
      final module = kProyekModules.firstWhere((item) => item.key == key);
      return _QuickAction(
        icon: module.icon,
        label: module.label,
        route: moduleRouteFor(key)!,
      );
    }).toList();

    if (actions.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flash_on_rounded,
              size: 20,
              color: context.colors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Aksi Cepat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        AdaptiveGrid(
          compactColumns: actions.length.clamp(1, 2).toInt(),
          mediumColumns: 2,
          expandedColumns: 4,
          spacing: 12,
          children: [
            for (final action in actions) _QuickActionButton(action: action),
          ],
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(action.route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          minHeight: TouchTargets.buttonMinHeight(context),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: context.colors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              action.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
