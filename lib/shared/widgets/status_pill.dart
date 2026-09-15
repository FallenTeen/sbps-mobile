import 'package:flutter/material.dart';

/// Badge status terstandarisasi (Rencana Pengembangan UX Fase C3).
///
/// Menggantikan pola `Container` manual yang berulang (bg warna α10% +
/// teks 11px w700). Punya dua mode: [filled=false] = tinted (bg warna α12%
/// dengan teks warna solid), [filled=true] = solid (bg warna penuh, teks
/// putih) untuk status yang harus menonjol (mis. "Tersedia", "Selesai").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    this.borderRadius = 8,
    this.labelStyle,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final double borderRadius;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = filled ? color : color.withValues(alpha: 0.12);
    final foregroundColor = filled ? Colors.white : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            style:
                labelStyle ??
                TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
          ),
        ],
      ),
    );
  }
}
