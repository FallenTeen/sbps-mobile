import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Keypad numerik besar untuk input di lapangan (sarung tangan / satu tangan).
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onDecimal,
    this.decimalEnabled = false,
  });

  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onDecimal;
  final bool decimalEnabled;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _Key(label: row[i], onTap: () => onDigit(row[i]))),
                ],
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: decimalEnabled
                  ? _Key(label: ',', onTap: onDecimal ?? () {})
                  : const SizedBox(height: 56),
            ),
            const SizedBox(width: 8),
            Expanded(child: _Key(label: '0', onTap: () => onDigit('0'))),
            const SizedBox(width: 8),
            Expanded(
              child: _Key(
                icon: Icons.backspace_outlined,
                onTap: onBackspace,
                semanticLabel: 'Hapus',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: icon != null
                ? Icon(icon, size: 22, color: AppTheme.textSecondary)
                : Text(
                    label ?? '',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
