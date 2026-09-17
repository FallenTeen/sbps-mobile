import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import 'portal_providers.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/confirmation_dialog.dart';

/// Combined portal + role selection screen (Fase 2).
/// Replaces separate /portal and /pilih-role screens.
/// Shows both portal and role selection in one flow with smart defaults.
class CombinedSelectionScreen extends ConsumerStatefulWidget {
  const CombinedSelectionScreen({super.key});

  @override
  ConsumerState<CombinedSelectionScreen> createState() =>
      _CombinedSelectionScreenState();
}

class _CombinedSelectionScreenState
    extends ConsumerState<CombinedSelectionScreen> {
  AppPortal? _selectedPortal;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadSavedSelection();
  }

  Future<void> _loadSavedSelection() async {
    final portal = ref.read(selectedPortalProvider).value;
    final role = ref.read(activeRoleProvider);

    if (mounted) {
      setState(() {
        _selectedPortal = portal;
        _selectedRole = role;
      });
    }
  }

  Future<void> _submit() async {
    final portal = _selectedPortal;
    if (portal == null) return;

    // Save portal
    await ref.read(selectedPortalProvider.notifier).select(portal);

    // Portal Proyek butuh role; portal Presensi tidak.
    if (portal == AppPortal.proyek) {
      final role = _selectedRole;
      if (role == null) return;
      await ref.read(activeRoleProvider.notifier).switchRole(role);
    }

    ref.read(roleChoicePendingProvider.notifier).set(false);

    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _handleAutoSkip() async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;

    final canPresensi = canAccessPresensi(user);
    final canProyek = canAccessProyek(user);
    final roles = app2RolesOf(user);

    // Auto-skip if only one portal and it's Presensi (no role needed)
    if (canPresensi && !canProyek) {
      await ref
          .read(selectedPortalProvider.notifier)
          .select(AppPortal.presensi);
      if (mounted) {
        context.go('/home');
      }
      return;
    }

    // Auto-skip if only one role and Proyek portal AND user can't presensi
    if (canProyek && !canPresensi && roles.length == 1) {
      await ref.read(selectedPortalProvider.notifier).select(AppPortal.proyek);
      await ref.read(activeRoleProvider.notifier).switchRole(roles.first);
      ref.read(roleChoicePendingProvider.notifier).set(false);

      if (mounted) {
        context.go('/home');
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;

    if (user == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canPresensi = canAccessPresensi(user);
    final canProyek = canAccessProyek(user);
    final roles = app2RolesOf(user);

    // Auto-skip on first build if applicable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAutoSkip();
    });

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _Header(
                user: user,
                onLogout: () async {
                  final result = await confirmLogout(context);
                  if (result?.confirmed == true) {
                    ref.read(authControllerProvider.notifier).logout();
                  }
                },
              ),

              // Selection content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // Portal selection
                    if (canPresensi && canProyek) ...[
                      Text(
                        'Pilih Portal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PortalSelection(
                        selected: _selectedPortal,
                        onSelected: (portal) {
                          setState(() {
                            _selectedPortal = portal;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Role selection (only for Proyek portal)
                    if ((canProyek && !canPresensi) ||
                        _selectedPortal == AppPortal.proyek) ...[
                      Text(
                        'Pilih Peran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RoleSelection(
                        roles: roles,
                        selected: _selectedRole,
                        onSelected: (role) {
                          setState(() {
                            _selectedRole = role;
                          });
                        },
                      ),
                      SizedBox(height: 24),
                    ],

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        onPressed: _canSubmit() ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          disabledBackgroundColor: context.colors.primary
                              .withValues(alpha: 0.3),
                        ),
                        child: const Text(
                          'Lanjut',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    // Footer
                    Center(
                      child: Text(
                        'SBPS Mobile v1.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSubmit() {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return false;

    // Portal Presensi: cukup portal saja, tidak butuh role.
    if (_selectedPortal == AppPortal.presensi) {
      return canAccessPresensi(user);
    }

    // Portal Proyek: butuh portal + role.
    if (_selectedPortal == AppPortal.proyek) {
      return canAccessProyek(user) && _selectedRole != null;
    }

    return false;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onLogout});

  final dynamic user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                (user.name ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${user.name ?? ''}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pilih pekerjaan Anda',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: Icon(
              Icons.logout_rounded,
              color: context.colors.textTertiary,
            ),
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _PortalSelection extends StatelessWidget {
  const _PortalSelection({required this.selected, required this.onSelected});

  final AppPortal? selected;
  final ValueChanged<AppPortal> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PortalOption(
          icon: Icons.fingerprint_rounded,
          title: 'SBPS Presensi',
          subtitle: 'Presensi & kehadiran',
          description:
              'Catat kehadiran, lihat riwayat presensi, dan kelola formulir lapangan.',
          gradient: AppTheme.primaryGradient,
          isSelected: selected == AppPortal.presensi,
          onTap: () => onSelected(AppPortal.presensi),
        ),
        const SizedBox(height: 12),
        _PortalOption(
          icon: Icons.engineering_rounded,
          title: 'SBPS Proyek',
          subtitle: 'Operasional & proyek',
          description:
              'Kelola armada, produksi, dashboard, dan modul operasional lainnya.',
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          isSelected: selected == AppPortal.proyek,
          onTap: () => onSelected(AppPortal.proyek),
        ),
      ],
    );
  }
}

class _PortalOption extends StatelessWidget {
  const _PortalOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Gradient gradient;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        elevation: isSelected ? 2 : 1,
        shadowColor: (gradient as LinearGradient).colors.first.withValues(
          alpha: 0.15,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? (gradient as LinearGradient).colors.first
                    : context.colors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Icon with gradient background
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (gradient as LinearGradient).colors.first
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 16),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: (gradient as LinearGradient).colors.first,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textTertiary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Selection indicator
                if (isSelected)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (gradient as LinearGradient).colors.first
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 20,
                      color: (gradient as LinearGradient).colors.first,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleSelection extends StatelessWidget {
  const _RoleSelection({
    required this.roles,
    required this.selected,
    required this.onSelected,
  });

  final List<String> roles;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final role in roles)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RoleOption(
              role: role,
              isSelected: selected == role,
              onTap: () => onSelected(role),
            ),
          ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final String role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.card,
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 2 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? context.colors.primary
                  : context.colors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
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
                  _iconForRole(role),
                  size: 24,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _descriptionForRole(role),
                      style: TextStyle(
                        color: context.colors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: context.colors.primary,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForRole(String role) {
    switch (role) {
      case 'Mandor Titik':
        return Icons.engineering;
      case 'Kontraktor':
        return Icons.business_center;
      case 'Admin Keuangan':
        return Icons.account_balance_wallet;
      case 'Owner':
        return Icons.supervisor_account;
      case 'Driver Armada':
        return Icons.local_shipping;
      case 'Kepala Divisi Armada':
      case 'Ketua Divisi Armada':
      case 'Ketua Armada':
        return Icons.supervisor_account;
      case 'Workshop':
        return Icons.build;
      case 'Inventory':
        return Icons.inventory_2;
      case 'Operator Mesin':
        return Icons.precision_manufacturing;
      default:
        return Icons.badge;
    }
  }

  String _descriptionForRole(String role) {
    switch (role) {
      case 'Mandor Titik':
        return 'Sesi produksi, QC, dan progres titik';
      case 'Kontraktor':
        return 'Dashboard operasional non-finansial';
      case 'Owner':
        return 'Akses penuh termasuk finansial';
      case 'Admin Keuangan':
        return 'Dashboard finansial dan tracking';
      case 'Driver Armada':
        return 'Unit saya, checklist, ritase, dan servis';
      case 'Kepala Divisi Armada':
      case 'Ketua Divisi Armada':
      case 'Ketua Armada':
        return 'Overview armada dan approval';
      case 'Workshop':
        return 'Antrian servis dan todo per job';
      case 'Inventory':
        return 'Stok barang dan request sparepart';
      case 'Operator Mesin':
        return 'Sesi produksi, mesin, dan uji QC';
      default:
        return '';
    }
  }
}
