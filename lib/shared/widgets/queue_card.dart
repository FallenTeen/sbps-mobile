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
    this.padding = const EdgeInsets.all(14),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final Color? statusColor;
  final String? statusLabel;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
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
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (statusLabel != null)
                            StatusPill(
                              label: statusLabel!,
                              color: statusColor ?? AppTheme.primaryColor,
                            ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
