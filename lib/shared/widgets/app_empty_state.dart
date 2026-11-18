import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/touch_targets.dart';
import 'illustrated_empty_state.dart';

/// Reusable and consistent empty state with muted icon, title, subtitle,
/// and optional action button. Wrapped with gentle fade-in animation.
///
/// Can also render [IllustratedEmptyState] variant for richer visuals.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
    this.illustrationVariant,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final EmptyStateVariant? illustrationVariant;

  @override
  Widget build(BuildContext context) {
    if (illustrationVariant != null) {
      return IllustratedEmptyState(
        variant: illustrationVariant!,
        title: title,
        subtitle: subtitle,
        actionLabel: actionLabel,
        onAction: onAction,
        padding: padding,
      );
    }

    return Semantics(
      label: '$title. ${subtitle ?? ""}',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: Center(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: TouchTargets.iconLarge,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.vGapMd,
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  AppSpacing.vGapXs,
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  AppSpacing.vGapLg,
                  FilledButton.tonal(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(TouchTargets.minTap, TouchTargets.minTap),
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}