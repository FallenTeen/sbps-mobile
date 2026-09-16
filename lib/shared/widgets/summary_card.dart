import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Kartu ringkasan bergradien — pola "Summary Card".
///
/// Dipakai di bagian atas halaman untuk menampilkan angka penting
/// (mis. jumlah sesi aktif, jumlah unit, ringkasan antrian). Menggunakan
/// `AppTheme.primaryGradient` sebagai identitas visual SBPS; teks putih
/// kontras AA di atas primary/merah (Design System).
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    this.title,
    this.value,
    this.subtitle,
    this.icon,
    this.onTap,
    this.badge,
    this.valueStyle,
    this.gradient,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
  });

  /// Label kecil di atas nilai (mis. "Ringkasan Sesi").
  final String? title;

  /// Angka penting utama (mis. "12 sesi aktif").
  final String? value;

  /// Deskripsi tambahan di bawah [value].
  final String? subtitle;

  /// Ikon di sisi kanan (opsional).
  final IconData? icon;

  /// Aksi saat kartu diketuk (opsional — menampilkan chevron).
  final VoidCallback? onTap;

  /// Konten tambahan di kanan (mis. jumlah QC tertunda) — mengalahkan [icon].
  final Widget? badge;

  final TextStyle? valueStyle;
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = gradient ?? AppTheme.primaryGradient;
    final hasTap = onTap != null;

    final leadingColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null && title!.isNotEmpty) ...[
          Text(
            title!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (value != null && value!.isNotEmpty)
          Text(
            value!,
            style:
                valueStyle ??
                theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
          ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ],
    );

    Widget? trailingWidget = badge;
    if (trailingWidget == null && icon != null) {
      trailingWidget = Icon(icon, color: Colors.white, size: 28);
    }

    final contentRow = trailingWidget != null
        ? Row(
            children: [
              Expanded(child: leadingColumn),
              const SizedBox(width: 12),
              trailingWidget,
            ],
          )
        : leadingColumn;

    final body = Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: padding,
      decoration: BoxDecoration(
        gradient: resolved,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: contentRow,
    );

    if (!hasTap) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: body,
      ),
    );
  }
}