import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Judul section konsisten untuk mengelompokkan konten — pola "Section Header".
///
/// Dipakai sebelum kartu/list di dalam halaman. Ukuran 15–16 / 600 sesuai
/// Design System global, dengan aksi opsional di kanan (mis. "Lihat Semua").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(left: 16, right: 16, bottom: 8),
  });

  /// Label section.
  final String title;

  /// Widget trailing opsional (mis. `TextButton` "Lihat Semua").
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
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