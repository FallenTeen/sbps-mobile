import 'package:flutter/material.dart';
import '../theme/touch_targets.dart';

/// Empty state with gradient badge + Material icon (no assets required).
///
/// Replaces SVG illustrations with pure Flutter rendering.
/// Variants cover all common empty states.
class IllustratedEmptyState extends StatelessWidget {
  const IllustratedEmptyState({
    super.key,
    required this.variant,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
  });

  final EmptyStateVariant variant;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _variantConfig[variant]!;
    final colors = config.gradientColors;

    return Semantics(
      label: '${title ?? config.defaultTitle}. ${subtitle ?? config.defaultSubtitle}',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: Center(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.first.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    config.icon,
                    size: TouchTargets.iconHero,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title ?? config.defaultTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else if (config.defaultSubtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    config.defaultSubtitle!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(TouchTargets.minTap, TouchTargets.minTap),
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Predefined empty state variants.
enum EmptyStateVariant {
  noData,
  noResults,
  offline,
  noPermission,
  success,
  error,
}

class _EmptyStateConfig {
  const _EmptyStateConfig({
    required this.icon,
    required this.gradientColors,
    required this.defaultTitle,
    this.defaultSubtitle,
  });

  final IconData icon;
  final List<Color> gradientColors;
  final String defaultTitle;
  final String? defaultSubtitle;
}

final Map<EmptyStateVariant, _EmptyStateConfig> _variantConfig = {
  EmptyStateVariant.noData: _EmptyStateConfig(
    icon: Icons.inbox_outlined,
    gradientColors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    defaultTitle: 'Belum ada data',
    defaultSubtitle: 'Data akan muncul di sini saat tersedia',
  ),
  EmptyStateVariant.noResults: _EmptyStateConfig(
    icon: Icons.search_off_outlined,
    gradientColors: [Color(0xFF6366F1), Color(0xFF818CF8)],
    defaultTitle: 'Tidak ditemukan',
    defaultSubtitle: 'Coba ubah kata kunci atau filter pencarian',
  ),
  EmptyStateVariant.offline: _EmptyStateConfig(
    icon: Icons.cloud_off_outlined,
    gradientColors: [Color(0xFF64748B), Color(0xFF94A3B8)],
    defaultTitle: 'Mode offline',
    defaultSubtitle: 'Perubahan akan disinkron saat online kembali',
  ),
  EmptyStateVariant.noPermission: _EmptyStateConfig(
    icon: Icons.lock_outline_rounded,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    defaultTitle: 'Akses dibatasi',
    defaultSubtitle: 'Hubungi admin untuk mendapatkan izin',
  ),
  EmptyStateVariant.success: _EmptyStateConfig(
    icon: Icons.check_circle_outline_rounded,
    gradientColors: [Color(0xFF047857), Color(0xFF10B981)],
    defaultTitle: 'Selesai',
    defaultSubtitle: 'Data berhasil disimpan dan dikirim',
  ),
  EmptyStateVariant.error: _EmptyStateConfig(
    icon: Icons.error_outline_rounded,
    gradientColors: [Color(0xFFB91C1C), Color(0xFFDC2626)],
    defaultTitle: 'Terjadi kesalahan',
    defaultSubtitle: 'Coba lagi atau hubungi dukungan teknis',
  ),
};