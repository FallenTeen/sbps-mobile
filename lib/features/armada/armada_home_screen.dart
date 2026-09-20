import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/armada_jenis.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/adaptive_grid.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/brand_strip.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/sync_action_button.dart';
import '../auth/auth_providers.dart';
import 'armada_providers.dart';
import 'driver_dashboard_screen.dart';
import 'unit_saya_home_screen.dart';
import 'models/armada.dart';

/// ArmadaHomeScreen — role-aware menu.
/// Menu ditampilkan berdasarkan sub-permission role yang login,
/// dikelompokkan per section dengan judul.
class ArmadaHomeScreen extends ConsumerWidget {
  const ArmadaHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeRole = ref.watch(activeRoleProvider);

    // Driver Armada → UnitSayaHomeScreen (workflow-based)
    if (activeRole == 'Driver Armada') {
      return UnitSayaHomeScreen();
    }

    final sections = _buildSections(activeRole);

    final isManager = _isManager(activeRole);
    final armadaAsync = ref.watch(armadaSayaProvider);
    final hasArmada = armadaAsync.value?.isNotEmpty == true;
    final showKendaraanSaya = !isManager || hasArmada;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Armada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              _subtitleForRole(activeRole),
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textTertiary,
              ),
            ),
          ],
        ),
        bottom: const BrandStrip(),
        actions: [PortalSwitchButton(), SyncActionButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          ref.invalidate(armadaSayaProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
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
                  Icon(_iconForRole(activeRole), color: Colors.white, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Armada',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitleForRole(activeRole),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Untuk driver: Kendaraan Saya tampil di atas
            if (!isManager && showKendaraanSaya) ...[
              _buildKendaraanSayaHeader(context),
              const SizedBox(height: 10),
              ..._armadaSection(ref),
              SizedBox(height: 24),
            ],

            // Role-aware menu sections
            for (final section in sections) ...[
              Row(
                children: [
                  Icon(section.icon, size: 20, color: context.colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    section.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AdaptiveGrid(
                compactColumns: 1,
                mediumColumns: 2,
                expandedColumns: 3,
                spacing: 8,
                children: [
                  for (final item in section.items)
                    _MenuTile(
                      icon: item.icon,
                      title: item.title,
                      subtitle: item.subtitle,
                      badge: item.badge,
                      onTap: () => item.onTap(context),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Untuk manager: Kendaraan Saya hanya tampil jika memang ada unit yang dipegang
            if (isManager && showKendaraanSaya) ...[
              _buildKendaraanSayaHeader(context),
              const SizedBox(height: 10),
              ..._armadaSection(ref),
              SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKendaraanSayaHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.directions_bus_rounded,
          size: 20,
          color: context.colors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Kendaraan Saya',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  static bool _isManager(String? role) =>
      role == 'Kepala Divisi Armada' ||
      role == 'Ketua Divisi Armada' ||
      role == 'Ketua Armada' ||
      role == 'Owner' ||
      role == 'Admin Keuangan';

  List<Widget> _armadaSection(WidgetRef ref) {
    final armada = ref.watch(armadaSayaProvider);
    return switch (armada) {
      AsyncData(value: final items) =>
        items.isEmpty
            ? const [_EmptyArmada()]
            : [for (final a in items) _ArmadaCard(armada: a)],
      AsyncError() => [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: AppEmptyState(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            icon: Icons.cloud_off_outlined,
            title: 'Gagal memuat data armada',
            subtitle:
                'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
            actionLabel: 'Muat Ulang',
            onAction: () => ref.invalidate(armadaSayaProvider),
          ),
        ),
      ],
      _ => const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };
  }

  String _subtitleForRole(String? role) {
    return switch (role) {
      'Driver Armada' => 'Tugas Harian & Operasional',
      'Kepala Divisi Armada' ||
      'Ketua Divisi Armada' ||
      'Ketua Armada' => 'Monitoring & Approval',
      'Owner' => 'Monitoring & Approval',
      'Admin Keuangan' => 'Monitoring & Approval',
      _ => 'Kendaraan & operasional harian',
    };
  }

  IconData _iconForRole(String? role) {
    return switch (role) {
      'Driver Armada' => Icons.local_shipping_rounded,
      'Kepala Divisi Armada' ||
      'Ketua Divisi Armada' ||
      'Ketua Armada' => Icons.supervisor_account_rounded,
      'Owner' => Icons.admin_panel_settings_rounded,
      'Admin Keuangan' => Icons.account_balance_wallet_rounded,
      _ => Icons.local_shipping_rounded,
    };
  }

  List<_MenuSection> _buildSections(String? role) {
    return switch (role) {
      'Driver Armada' => _driverSections(),
      'Kepala Divisi Armada' ||
      'Ketua Divisi Armada' ||
      'Ketua Armada' => _kepalaDivisiSections(),
      'Owner' => _ownerSections(),
      'Admin Keuangan' => _adminKeuanganSections(),
      _ => _driverSections(), // default
    };
  }

  List<_MenuSection> _driverSections() => [
    _MenuSection(
      icon: Icons.task_alt_rounded,
      title: 'Tugas Harian Saya',
      items: [
        _MenuItem(
          icon: Icons.dashboard_outlined,
          title: 'Dashboard Saya',
          subtitle: 'Ringkasan kinerja & muatan hari ini',
          onTap: (ctx) => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => const DriverDashboardScreen(),
            ),
          ),
        ),
        _MenuItem(
          icon: Icons.checklist_rtl,
          title: 'Checklist Harian',
          subtitle: 'Catat kondisi kendaraan hari ini',
          onTap: (ctx) => ctx.push('/armada/checklist'),
        ),
        _MenuItem(
          icon: Icons.speed_outlined,
          title: 'KM Awal',
          subtitle: 'Catat KM awal kendaraan per muatan',
          onTap: (ctx) => ctx.push('/armada/odo-awal'),
        ),
        _MenuItem(
          icon: Icons.badge_outlined,
          title: 'Presensi Helper',
          subtitle: 'Absenkan helper armada hari ini',
          onTap: (ctx) => ctx.push('/armada/helper-presensi'),
        ),
      ],
    ),
    _MenuSection(
      icon: Icons.work_rounded,
      title: 'Operasional',
      items: [
        _MenuItem(
          icon: Icons.route_outlined,
          title: 'Riwayat Muatan',
          subtitle: 'Pengiriman & upah per muatan',
          onTap: (ctx) => ctx.push('/armada/ritase'),
        ),
        _MenuItem(
          icon: Icons.edit_road_outlined,
          title: 'Input Muatan',
          subtitle: 'Catat jumlah muatan & satuan hari ini',
          onTap: (ctx) => ctx.push('/armada/ritase-input'),
        ),
        _MenuItem(
          icon: Icons.build_outlined,
          title: 'Servis Armada',
          subtitle: 'Pengajuan & riwayat perbaikan armada',
          onTap: (ctx) => ctx.push('/armada/servis'),
        ),
      ],
    ),
  ];

  List<_MenuSection> _kepalaDivisiSections() => [
    _MenuSection(
      icon: Icons.dashboard_rounded,
      title: 'Monitoring',
      items: [
        _MenuItem(
          icon: Icons.analytics_outlined,
          title: 'Overview Armada',
          subtitle: 'Status seluruh armada & dashboard',
          onTap: (ctx) => ctx.push('/armada/overview'),
        ),
        _MenuItem(
          icon: Icons.monitor_heart_outlined,
          title: 'Monitoring Armada',
          subtitle: 'Utilisasi (jam, HM/Jam) & kondisi seluruh armada',
          onTap: (ctx) => ctx.push('/armada/monitoring'),
        ),
        _MenuItem(
          icon: Icons.route_outlined,
          title: 'Riwayat Muatan Armada',
          subtitle: 'Monitoring pengiriman & ritase seluruh armada',
          onTap: (ctx) => ctx.push('/armada/ritase'),
        ),
      ],
    ),
    _MenuSection(
      icon: Icons.approval_rounded,
      title: 'Approval',
      items: [
        _MenuItem(
          icon: Icons.build_outlined,
          title: 'Servis Armada',
          subtitle: 'Persetujuan & riwayat perbaikan',
          onTap: (ctx) => ctx.push('/armada/servis'),
        ),
        _MenuItem(
          icon: Icons.assignment_outlined,
          title: 'Checklist Serah Terima',
          subtitle: 'Serah terima kondisi kendaraan',
          onTap: (ctx) => ctx.push('/armada/checklist-major'),
        ),
      ],
    ),
  ];

  List<_MenuSection> _ownerSections() => _kepalaDivisiSections();

  List<_MenuSection> _adminKeuanganSections() => [
    _MenuSection(
      icon: Icons.dashboard_rounded,
      title: 'Monitoring',
      items: [
        _MenuItem(
          icon: Icons.analytics_outlined,
          title: 'Overview Armada',
          subtitle: 'Status seluruh armada & dashboard',
          onTap: (ctx) => ctx.push('/armada/overview'),
        ),
      ],
    ),
    _MenuSection(
      icon: Icons.approval_rounded,
      title: 'Approval',
      items: [
        _MenuItem(
          icon: Icons.build_outlined,
          title: 'Servis Armada',
          subtitle: 'Persetujuan & riwayat perbaikan',
          onTap: (ctx) => ctx.push('/armada/servis'),
        ),
      ],
    ),
  ];
}

// ── Data Models ──────────────────────────────────────────────────────────────

class _MenuSection {
  const _MenuSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<_MenuItem> items;
}

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;
  final void Function(BuildContext) onTap;
}

// ── Menu Tile ─────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: context.colors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.colors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null && badge! > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.colors.warning,
                      ),
                    ),
                  ),
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
}

// ── Armada Card ───────────────────────────────────────────────────────────────

class _ArmadaCard extends StatelessWidget {
  const _ArmadaCard({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final aktif = armada.status == 'aktif' || armada.status == 'beroperasi';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: context.colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  armada.platNomor,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: aktif
                      ? context.colors.success.withValues(alpha: 0.1)
                      : context.colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  armada.status ?? '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: aktif
                        ? context.colors.success
                        : context.colors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (armada.jenis != null)
                _InfoChip(label: 'Jenis', value: _labelJenis(armada.jenis!)),
              if (armada.kodeUnit != null)
                _InfoChip(label: 'Unit', value: armada.kodeUnit!),
              if (armada.titikNama != null)
                _InfoChip(label: 'Titik', value: armada.titikNama!),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyArmada extends StatelessWidget {
  const _EmptyArmada();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.no_crash_outlined,
            size: 40,
            color: context.colors.textMuted,
          ),
          SizedBox(height: 10),
          Text(
            'Belum ada armada yang ditugaskan ke Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.error.withValues(alpha: 0.2)),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _labelJenis(String jenis) => labelJenisArmada(jenis);
