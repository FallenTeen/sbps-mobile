import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/animated_badge.dart';
import '../../shared/widgets/brand_strip.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../auth/auth_providers.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../notifikasi/notifikasi_screen.dart';
import '../../shared/widgets/sync_action_button.dart';
import '../tracking/tracking_providers.dart';
import 'role_permissions.dart';
import 'pending_summary_provider.dart';

class ProyekHomeScreen extends ConsumerWidget {
  const ProyekHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final role = ref.watch(activeRoleProvider);
    final roles = user == null ? const <String>[] : app2RolesOf(user);
    final allowed = kProyekModules
        .where((m) => RolePermissions.canAccess(role, m.key))
        .where((m) => m.key != 'tracking' || RolePermissions.isAdminLike(role))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: null,
        bottom: const BrandStrip(),
        actions: [
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
          const PortalSwitchButton(),
          const SyncActionButton(),
          const _NotifikasiBadgeAction(),
          if (roles.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Ganti peran',
              icon: const Icon(Icons.swap_horiz),
              onSelected: (r) =>
                  ref.read(activeRoleProvider.notifier).switchRole(r),
              itemBuilder: (context) => [
                for (final r in roles)
                  CheckedPopupMenuItem<String>(
                    value: r,
                    checked: r == role,
                    child: Text(r),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final result = await confirmLogout(context);
              if (result?.confirmed == true) {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
      body: role == null
          ? const _NoActiveRoleView()
          : ResponsiveCenter(
              maxWidth: AppBreakpoints.maxContentWidth,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // Greeting header
                  _GreetingHeader(user: user, role: role),
                  const SizedBox(height: 20),

                  if (role == 'Mandor Titik') ...[
                    const _TrackingStatusCard(),
                    const SizedBox(height: 16),
                  ],

                  // Pekerjaan Menunggu Anda card (Fase 2)
                  _PendingWorkCard(role: role),
                  const SizedBox(height: 16),

                  // Quick Actions per role (Fase 2)
                  _QuickActions(role: role),
                  const SizedBox(height: 16),

                  // Section: Modul
                  Row(
                    children: [
                      Icon(Icons.grid_view_rounded,
                          size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Modul',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (context.isTablet)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: allowed.length,
                      itemBuilder: (context, i) => StaggeredEntrance(
                        index: i,
                        child: _ModuleCard(module: allowed[i]),
                      ),
                    )
                  else
                    for (var i = 0; i < allowed.length; i++)
                      StaggeredEntrance(
                        index: i,
                        child: _ModuleCard(module: allowed[i]),
                      ),
                ],
              ),
            ),
    );
  }
}

// ── Greeting Header ───────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
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

// ── Module Card ───────────────────────────────────────────────────────────────

class _ModuleCard extends ConsumerWidget {
  const _ModuleCard({required this.module});

  final ProyekModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigate(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(module.icon, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitleFor(module.key),
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pending badge (Fase 2)
                _PendingBadge(moduleKey: module.key, role: role),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context) {
    switch (module.key) {
      case 'produksi':
        context.push('/produksi/sesi-aktif');
      case 'qc':
        context.push('/qc/riwayat');
      case 'tracking':
        context.push('/tracking/pengguna-aktif');
      case 'dashboard':
        context.push('/dashboard');
      case 'keuangan':
        context.push('/dashboard/keuangan');
      case 'armada':
        context.push('/armada');
      case 'kontraktor':
        context.push('/kontraktor/proyek');
      case 'workshop':
        context.push('/workshop');
      case 'inventory':
        context.push('/inventory');
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${module.label} belum tersedia')),
        );
    }
  }

  String _subtitleFor(String key) => switch (key) {
        'produksi' => 'Sesi aktif, mulai, riwayat, progress, QC',
        'qc' => 'Slump test & uji tekan, riwayat QC',
        'tracking' => 'User aktif & jejak lokasi',
        'dashboard' => 'Ringkasan titik & operasional',
        'keuangan' => 'Chart keuangan, PO, invoice',
        'armada' => 'Kendaraan, ritase & checklist harian',
        'kontraktor' => 'Proyek kontrak, progress, invoice & chat',
        'workshop' => 'Antrian servis, checklist pengerjaan & sparepart',
        'inventory' => 'Stok barang, request sparepart & opname',
        _ => 'Menyusul di fase berikutnya',
      };
}

IconData _iconForRole(String role) => switch (role) {
      'Mandor Titik' => Icons.engineering_rounded,
      'Kontraktor' => Icons.business_center_rounded,
      'Admin Keuangan' => Icons.account_balance_wallet_rounded,
      'Owner' => Icons.supervisor_account_rounded,
      'Driver Armada' => Icons.local_shipping_rounded,
      _ => Icons.badge_rounded,
    };

// ── Tracking Status ───────────────────────────────────────────────────────────

class _TrackingStatusCard extends ConsumerWidget {
  const _TrackingStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(trackingSchedulerProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.running
              ? AppTheme.successColor.withValues(alpha: 0.3)
              : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: status.running
                  ? AppTheme.successColor.withValues(alpha: 0.1)
                  : AppTheme.surfaceVariantColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              status.running ? Icons.location_on_rounded : Icons.location_off_rounded,
              color: status.running ? AppTheme.successColor : AppTheme.textMuted,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (status.message != null)
                  Text(
                    status.message!,
                    style: const TextStyle(color: AppTheme.errorColor, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (status.pendingPoints > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${status.pendingPoints} antre',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Notifikasi Badge ──────────────────────────────────────────────────────────

class _NotifikasiBadgeAction extends ConsumerWidget {
  const _NotifikasiBadgeAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);

    return IconButton(
      tooltip: 'Notifikasi',
      icon: AnimatedCountBadge(
        count: count,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotifikasiScreen()),
        );
        ref.read(unreadCountProvider.notifier).reload();
      },
    );
  }
}

// ── No Active Role ────────────────────────────────────────────────────────────

class _NoActiveRoleView extends StatelessWidget {
  const _NoActiveRoleView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_off_outlined,
                  size: 40, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Peran aktif tidak tersedia untuk App Proyek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pekerjaan Menunggu Anda Card (Fase 2) ───────────────────────────────────────

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
            gradient: const LinearGradient(
              colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items,
    );
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

// ── Pending Badge (Fase 2) ─────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.warningColor,
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
      default:
        return 0;
    }
  }
}

// ── Quick Actions per Role (Fase 2) ───────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final actions = _getActionsForRole(role);
    
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on_rounded,
                size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Aksi Cepat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _QuickActionButton(action: actions[i])),
            ],
          ],
        ),
      ],
    );
  }
  
  List<_QuickAction> _getActionsForRole(String? role) {
    switch (role) {
      case 'Driver Armada':
        return [
          _QuickAction(
            icon: Icons.checklist,
            label: 'Checklist',
            route: '/armada/checklist',
          ),
          _QuickAction(
            icon: Icons.add_road,
            label: 'Ritase',
            route: '/armada/ritase-input',
          ),
          _QuickAction(
            icon: Icons.build,
            label: 'Servis',
            route: '/armada/servis/ajuan',
          ),
        ];
      case 'Mandor Titik':
        return [
          _QuickAction(
            icon: Icons.play_circle,
            label: 'Mulai Sesi',
            route: '/produksi/mulai',
          ),
          _QuickAction(
            icon: Icons.science,
            label: 'QC Test',
            route: '/qc/riwayat',
          ),
        ];
      case 'Workshop':
        return [
          _QuickAction(
            icon: Icons.build_circle,
            label: 'Antrian',
            route: '/workshop',
          ),
        ];
      default:
        return [];
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              action.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
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
