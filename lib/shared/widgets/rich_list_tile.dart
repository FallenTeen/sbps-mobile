import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// RichListTile — pola list item berlapis untuk daftar record.
///
/// Struktur visual:
/// ```
/// [leading status]  Judul/Identifier utama        [meta badge]  [trailing]
///                   Baris status (subtitle)
/// ```
///
/// Leading icon menampung status warna (abu = belum, amber = mendekati
/// tenggat/overdue, hijau = selesai), subtitle menampung deskripsi status,
/// dan `meta` opsional menampilkan badge kecil (kategori / info tambahan).
/// `trailing` default berupa chevron jika `onTap` disediakan.
class RichListTile extends StatelessWidget {
  const RichListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.metaColor,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  final String title;

  /// Baris status tambahan (contoh: "Belum dicatat hari ini · Terakhir: 2 hari lalu").
  final String? subtitle;

  /// Badge meta opsional — kategori, prioritas, atau info tambahan.
  final String? meta;

  /// Warna badge meta. Default [context.colors.textTertiary].
  final Color? metaColor;

  /// Leading icon/status (opsional). Beri carrying color & shape sendiri.
  final Widget? leading;

  /// Trailing widget. Default: chevron kanan jika [onTap] tidak null.
  final Widget? trailing;

  final VoidCallback? onTap;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hasMeta = meta != null && meta!.isNotEmpty;
    final trailingWidget =
        trailing ??
        (onTap != null ? const Icon(Icons.chevron_right_rounded) : null);

    return Semantics(
      label: hasMeta
          ? '$title, $subtitle, $meta'
          : subtitle != null
          ? '$title, $subtitle'
          : title,
      button: onTap != null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
          boxShadow: AppTheme.shadowLv1,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                            ),
                            if (hasMeta) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (metaColor ?? context.colors.textTertiary)
                                          .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  meta!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        metaColor ??
                                        context.colors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(width: 8),
                    trailingWidget,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
