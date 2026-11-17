import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Judul section konsisten untuk mengelompokkan konten - pola "Section Header".
///
/// Dipakai sebelum kartu/list di dalam halaman. Ukuran 15–16 / 600 sesuai
/// Design System global, dengan aksi opsional di kanan (mis. "Lihat Semua").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.leadingIcon,
    this.helper,
    this.padding = const EdgeInsets.only(left: 16, right: 16, bottom: 8),
  });

  /// Label section.
  final String title;

  /// Widget trailing opsional (mis. `TextButton` "Lihat Semua").
  final Widget? trailing;

  /// Ikon kecil di depan judul (opsional, untuk form/profile section).
  final IconData? leadingIcon;

  /// Teks bantuan di bawah judul (opsional).
  final String? helper;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 18, color: context.colors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                if (helper != null && helper!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    helper!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}