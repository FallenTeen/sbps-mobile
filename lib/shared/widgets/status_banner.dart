import 'package:flutter/material.dart';

class StatusConfig {
  const StatusConfig({
    required this.label,
    required this.color,
    this.icon,
    this.progress,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double? progress;
}

class StatusAction {
  const StatusAction({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final IconData? icon;
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.status,
    this.actions = const [],
    this.showProgressRing = false,
    this.progress,
    this.margin = const EdgeInsets.fromLTRB(16, 16, 16, 0),
  });

  final StatusConfig status;
  final List<StatusAction> actions;
  final bool showProgressRing;
  final double? progress;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showProgressRing) ...[
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: progress ?? status.progress,
                    color: status.color,
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (status.icon != null) ...[
                Icon(status.icon, color: status.color, size: 24),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  status.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ),
            ],
          ),
          if (status.progress != null && !showProgressRing) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: status.progress,
                backgroundColor: status.color.withValues(alpha: 0.24),
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
                minHeight: 6,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions.map((action) {
                if (action.isPrimary) {
                  return FilledButton.icon(
                    onPressed: action.onPressed,
                    icon: action.icon != null
                        ? Icon(action.icon, size: 18)
                        : const SizedBox.shrink(),
                    label: Text(action.label),
                  );
                }
                return OutlinedButton.icon(
                  onPressed: action.onPressed,
                  icon: action.icon != null
                      ? Icon(action.icon, size: 18)
                      : const SizedBox.shrink(),
                  label: Text(action.label),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
