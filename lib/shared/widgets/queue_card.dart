import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'status_pill.dart';

/// Kartu list generik untuk "antrian kerja" — dipakai di WorkshopQueueScreen
/// dan section request di InventoryHomeScreen. Konsisten style dengan
/// AppEmptyState/SkeletonLoader yang sudah ada.
class QueueCard extends StatelessWidget {
  const QueueCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.statusColor,
    this.statusLabel,
    this.onTap,
    this.badgeLabel,
    this.badgeColor,
    this.highlighted = false,
    this.padding = const EdgeInsets.all(14),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final Color? statusColor;
  final String? statusLabel;

  /// Label kecil di bawah status pill (mis. "Menunggu Sparepart").
  final String? badgeLabel;
  final Color? badgeColor;

  /// Sorot kartu saat terpilih (mode master-detail tablet).
  final bool highlighted;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? context.colors.primary
              : context.colors.border,
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: AppTheme.shadowLv2,
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
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                          if (statusLabel != null)
                            StatusPill(
                              label: statusLabel!,
                              color: statusColor ?? context.colors.primary,
                            ),
                        ],
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? context.colors.warning)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeLabel!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color:
                                    badgeColor ?? context.colors.warning,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textTertiary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
