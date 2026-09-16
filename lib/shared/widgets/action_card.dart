import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kartu aksi berdiri — pola "Action Card".
///
/// Mengkonsolidasikan pola kartu berisi ikon + judul + deskripsi singkat
/// yang bila diketuk menjalankan suatu aksi (mis. "Mulai Ritase",
/// "Input ODO", "Mulai Sesi"). Layout vertikal ikon di tengah-atas,
/// kontras AA untuk ikon dan teks (Design System Global).
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.dense = false,
  });

  final IconData icon;
  final String title;

  /// Deskripsi singkat (opsional).
  final String? subtitle;

  final VoidCallback onTap;

  /// Warna ikon — default [context.colors.primary].
  final Color? iconColor;

  /// Mode ringkas: padding lebih kecil, ikon 24 (tanpa subtitle).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? context.colors.primary;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: AppTheme.shadowLv1,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(dense ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: dense ? 24 : 28,
                  color: color,
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (!dense && subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
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