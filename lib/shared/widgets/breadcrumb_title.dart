import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Judul kontekstual (Rencana Pengembangan UX Fase A3) untuk AppBar layar
/// detail. Menampilkan "crumb" induk di baris kecil (mis. nama modul / item
/// utama) plus judul utama, sehingga pengguna selalu tahu konteks mereka.
/// Mengikuti konvensi light AppBar (foreground gelap di atas surface terang).
class BreadcrumbTitle extends StatelessWidget {
  const BreadcrumbTitle({
    super.key,
    this.parentLabel,
    this.title,
    this.prefix,
  });

  /// Baris kecil di atas: nama modul / konteks induk (boleh kosong).
  final String? parentLabel;

  /// Judul utama layar detail.
  final String? title;

  /// Ikon/alias kecil opsional di depan judul (mis. ikon status).
  final Widget? prefix;

  bool get _hasParent =>
      parentLabel != null && parentLabel!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasParent)
          Text(
            parentLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefix != null) ...[
              prefix!,
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}