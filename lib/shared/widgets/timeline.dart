import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Status titik timeline.
enum TimelineStatus { done, current, pending }

/// Model item garis waktu — pola "Timeline".
class TimelineItem {
  const TimelineItem({
    required this.title,
    this.subtitle,
    this.timeLabel,
    required this.status,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// Label waktu/status tambahan di kanan (opsional).
  final String? timeLabel;

  final TimelineStatus status;
  final VoidCallback? onTap;
}

/// Garis waktu vertikal dengan titik status berwarna.
///
/// Konsisten dengan WorkflowStepper (step indicator) — titik hijau = selesai,
/// merah = sedang, abu = belum. Dipakai untuk riwayat / proses bertahap.
class Timeline extends StatelessWidget {
  const Timeline({super.key, required this.items, this.padding = const EdgeInsets.symmetric(vertical: 4)});

  final List<TimelineItem> items;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _TimelineRow(item: items[i], isLast: i == items.length - 1),
          ],
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.isLast});

  final TimelineItem item;
  final bool isLast;

  Color _statusColor(BuildContext context) {
    return switch (item.status) {
      TimelineStatus.done => context.colors.success,
      TimelineStatus.current => context.colors.primary,
      TimelineStatus.pending => context.colors.textMuted,
    };
  }

  IconData _statusIcon() {
    return switch (item.status) {
      TimelineStatus.done => Icons.check_circle_rounded,
      TimelineStatus.current => Icons.radio_button_checked_rounded,
      TimelineStatus.pending => Icons.radio_button_unchecked_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(context);

    return Semantics(
      label: item.title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titik + garis penghubung.
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Icon(_statusIcon(), size: 20, color: color),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 32,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16, top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          if (item.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (item.timeLabel != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        item.timeLabel!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}