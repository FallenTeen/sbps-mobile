import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pengelompokan field form — pola "Form Section".
///
/// Membungkus satu kelompok field (label + input) ke dalam kartu berdampingan
/// dengan judul section opsional. Jarak antar field default 12 (Design System
/// input gap). Dipakai untuk menyatukan tampilan form di seluruh layar.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.spacing = 12,
    this.padding = const EdgeInsets.all(16),
    this.showBorder = false,
  });

  /// Judul kecil di atas kartu (opsional).
  final String? title;

  /// Aksi di kanan judul (opsional).
  final Widget? trailing;

  /// Field-field form dalam section ini.
  final List<Widget> children;

  /// Jarak vertikal antar [children].
  final double spacing;

  final EdgeInsetsGeometry padding;

  /// Jika `true`, kartu memakai border (default: shadow Lv1, tanpa border).
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasTitle = title != null && title!.isNotEmpty;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: showBorder
            ? Border.all(color: context.colors.border)
            : null,
        boxShadow: AppTheme.shadowLv1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            children[i],
          ],
        ],
      ),
    );
  }
}