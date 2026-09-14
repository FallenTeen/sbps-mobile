import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import 'portal_providers.dart';
import '../../shared/theme/app_theme.dart';

/// Halaman pemilih portal: Presensi atau Proyek.
/// Tampil setelah login jika user punya akses ke kedua portal.
class PortalSelectionScreen extends ConsumerWidget {
  const PortalSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    if (user == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final canPresensi = canAccessPresensi(user);
    final canProyek = canAccessProyek(user);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              _Header(user: user, onLogout: () => ref.read(authControllerProvider.notifier).logout()),

              // ── Portal Cards ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _PortalCard(
                      icon: Icons.fingerprint_rounded,
                      title: 'SBPS Presensi',
                      subtitle: 'Presensi & kehadiran',
                      description: 'Catat kehadiran, lihat riwayat presensi, dan kelola formulir lapangan.',
                      gradient: AppTheme.primaryGradient,
                      enabled: canPresensi,
                      disabledMessage: 'Anda tidak memiliki akses ke portal ini',
                      onTap: () async {
                        await ref
                            .read(selectedPortalProvider.notifier)
                            .select(AppPortal.presensi);
                        if (context.mounted) context.go('/home');
                      },
                    ),
                    const SizedBox(height: 16),
                    _PortalCard(
                      icon: Icons.engineering_rounded,
                      title: 'SBPS Proyek',
                      subtitle: 'Operasional & proyek',
                      description: 'Kelola armada, produksi, dashboard, dan modul operasional lainnya.',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      enabled: canProyek,
                      disabledMessage: 'Anda tidak memiliki akses ke portal ini',
                      onTap: () async {
                        await ref
                            .read(selectedPortalProvider.notifier)
                            .select(AppPortal.proyek);
                        if (context.mounted) context.go('/home');
                      },
                    ),
                    SizedBox(height: 32),
                    // ── Footer ──
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
}

/// Header with greeting and logout.
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
                  'Pilih portal yang ingin Anda gunakan',
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
            icon: Icon(Icons.logout_rounded, color: context.colors.textTertiary),
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

/// Portal card with gradient icon and polished design.
class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradient,
    required this.enabled,
    required this.disabledMessage,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Gradient gradient;
  final bool enabled;
  final String disabledMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        elevation: enabled ? 1 : 0,
        shadowColor: context.colors.primary.withValues(alpha: 0.15),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: enabled
                  ? null
                  : Border.all(color: context.colors.border, width: 1),
            ),
            child: Row(
              children: [
                // Icon with gradient background
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: enabled ? gradient : null,
                    color: enabled ? null : context.colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: (gradient as LinearGradient).colors.first
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: enabled ? Colors.white : context.colors.textMuted,
                  ),
                ),
                SizedBox(width: 16),
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
                          color: enabled
                              ? context.colors.textPrimary
                              : context.colors.textMuted,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: enabled
                              ? context.colors.primary
                              : context.colors.textMuted,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        enabled ? description : disabledMessage,
                        style: TextStyle(
                          fontSize: 12,
                          color: enabled
                              ? context.colors.textTertiary
                              : context.colors.textMuted,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                // Arrow
                if (enabled)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: context.colors.primary,
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
