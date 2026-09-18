import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'submit_spinner.dart';

/// Bilah aksi menempel di bawah layar — pola "Sticky Action Bar".
///
/// Menampilkan tombol utama (dan opsi tombol sekunder) yang selalu terlihat
/// saat user scroll, dengan SafeArea bawah, shadow atas, dan warna surface
/// agar tetap kontras di mode terang & gelap. Touch target ≥48dp.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryIcon,
    this.showPrimaryLoading = false,
    this.secondaryDisabled = false,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Label tombol sekunder (opsional) — OutlinedButton di sebelah kiri.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Ikon di tombol utama (opsional).
  final IconData? primaryIcon;

  /// Jika `true`, tombol utama menampilkan spinner (submit in-flight).
  final bool showPrimaryLoading;

  /// Jika `true`, tombol sekunder nonaktif.
  final bool secondaryDisabled;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final hasSecondary =
        secondaryLabel != null && secondaryLabel!.isNotEmpty;
    final primaryBtn = FilledButton.icon(
      // minimumSize (bukan SizedBox fixed-height): label tetap bisa tumbuh
      // saat text scaling 130% tanpa terpotong, hit area tetap ≥48dp.
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
      onPressed: showPrimaryLoading ? null : onPrimary,
      icon: showPrimaryLoading
          ? const SubmitSpinner()
          : (primaryIcon != null
                ? Icon(primaryIcon, size: 18)
                : const SizedBox.shrink()),
      label: Text(primaryLabel),
    );

    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        boxShadow: AppTheme.shadowLv2,
        border: Border(
          top: BorderSide(color: context.colors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: hasSecondary
              ? Row(
                  children: [
                    if (onSecondary != null) ...[
                      Expanded(child: secondaryBtn(context)),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: primaryBtn),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: double.infinity, child: primaryBtn),
                  ],
                ),
        ),
      ),
    );
  }

  Widget secondaryBtn(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
      onPressed: secondaryDisabled ? null : onSecondary,
      icon: const Icon(Icons.chevron_left_rounded, size: 18),
      label: Text(secondaryLabel ?? 'Kembali'),
    );
  }
}