import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Baris label–nilai — pola "Key/Value Row".
///
/// Dipakai untuk menampilkan detail/info teknis secara konsisten:
/// label kecil di kiri (meta), nilai di kanan (lebih tegas), opsional ikon.
/// Menyediakan aksi salin ke clipboard bila [copyValue] diisi.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.copyValue,
    this.valueIsImportant = false,
    this.valueColor,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  final String label;
  final String value;

  /// Ikon kecil di depan nilai (opsional, mis. ikon status/tipe).
  final IconData? icon;

  /// Jika diisi, nilai dapat disalin (muncul ikon copy + snackbar).
  final String? copyValue;

  /// Jika `true`, nilai memakai angka penting (20px + bold).
  final bool valueIsImportant;

  final Color? valueColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canCopy = copyValue != null && copyValue!.isNotEmpty;
    final effectiveValueColor = valueColor ?? context.colors.textPrimary;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon!,
                    size: 16,
                    color: effectiveValueColor,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: valueIsImportant
                        ? theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: effectiveValueColor,
                          )
                        : theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: effectiveValueColor,
                          ),
                  ),
                ),
                if (canCopy) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: copyValue!)).then(
                        (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$label berhasil disalin'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}