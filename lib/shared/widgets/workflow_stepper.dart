import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Status setiap step dalam workflow.
enum WorkflowStepStatus { belum, sedang, selesai }

/// Model untuk 1 step dalam workflow.
class WorkflowStep {
  const WorkflowStep({
    required this.label,
    required this.status,
    this.subtitle,
    this.onTap,
  });

  final String label;
  final String? subtitle;
  final WorkflowStepStatus status;
  final VoidCallback? onTap;
}

/// Widget stepper horizontal yang menunjukkan posisi user dalam alur kerja.
/// Dipakai di UnitSayaHomeScreen (Driver) dan bisa direuse untuk Workshop/Inventory.
class WorkflowStepper extends StatelessWidget {
  const WorkflowStepper({
    super.key,
    required this.steps,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final List<WorkflowStep> steps;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alur Hari Ini',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(steps.length, (i) {
            final step = steps[i];
            final isLast = i == steps.length - 1;
            return _StepTile(
              step: step,
              index: i,
              isLast: isLast,
              theme: theme,
            );
          }),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.index,
    required this.isLast,
    required this.theme,
  });

  final WorkflowStep step;
  final int index;
  final bool isLast;
  final ThemeData theme;

  Color _statusColor(BuildContext context) {
    return switch (step.status) {
      WorkflowStepStatus.selesai => context.colors.success,
      WorkflowStepStatus.sedang => context.colors.primary,
      WorkflowStepStatus.belum => theme.colorScheme.outlineVariant,
    };
  }

  IconData _statusIcon() {
    return switch (step.status) {
      WorkflowStepStatus.selesai => Icons.check_circle_outline,
      WorkflowStepStatus.sedang => Icons.radio_button_checked,
      WorkflowStepStatus.belum => Icons.radio_button_unchecked,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    final isActive = step.status != WorkflowStepStatus.belum;
    final statusText = switch (step.status) {
      WorkflowStepStatus.selesai => 'Sudah selesai',
      WorkflowStepStatus.sedang => 'Sedang berlangsung',
      WorkflowStepStatus.belum => 'Belum dimulai',
    };

    return Semantics(
      button: step.onTap != null && step.status != WorkflowStepStatus.selesai,
      label:
          'Langkah ${index + 1}: ${step.label}. Status: $statusText${step.subtitle != null ? ". " + step.subtitle! : ""}',
      child: InkWell(
        onTap: step.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stepper column (icon + line)
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Icon(_statusIcon(), size: 24, color: color),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        color: isActive
                            ? color.withValues(alpha: 0.4)
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isActive
                              ? context.colors.textPrimary
                              : context.colors.textTertiary,
                          decoration: step.status == WorkflowStepStatus.selesai
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (step.subtitle != null) ...[
                        SizedBox(height: 2),
                        Text(
                          step.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: step.status == WorkflowStepStatus.selesai
                                ? context.colors.success
                                : context.colors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Action indicator
              if (step.onTap != null &&
                  step.status != WorkflowStepStatus.selesai)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
