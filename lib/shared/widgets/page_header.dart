import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Judul halaman konsisten untuk bagian atas konten — pola "Page Header".
///
/// Dipakai di dalam area scroll (bukan AppBar) supaya seluruh layar memiliki
/// judul dengan ukuran/berat yang sama: 20/700 (Design System global),
/// subtitle opsional, dan aksi/trailing opsional di kanan.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  /// Judul utama halaman.
  final String title;

  /// Baris kecil di bawah judul (deskripsi konteks singkat).
  final String? subtitle;

  /// Tombol/aksi di ujung kanan (mis. `IconButton` atau `TextButton`).
  final Widget? action;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 12),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}