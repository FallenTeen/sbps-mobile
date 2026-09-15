import 'package:flutter/material.dart';

/// Animated count badge using AnimatedSwitcher for smooth scale/fade transitions.
class AnimatedCountBadge extends StatelessWidget {
  const AnimatedCountBadge({
    super.key,
    required this.count,
    required this.child,
    this.badgeColor,
    this.textColor,
  });

  final int count;
  final Widget child;
  final Color? badgeColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = badgeColor ?? theme.colorScheme.error;
    final fg = textColor ?? theme.colorScheme.onError;

    return Semantics(
      label: count > 0 ? '$count notifikasi belum dibaca' : null,
      child: Badge(
        isLabelVisible: count > 0,
        backgroundColor: bg,
        textColor: fg,
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Text(
            '$count',
            key: ValueKey<int>(count),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Pulsing sync indicator dot when a background sync is active.
class PulsingSyncDot extends StatefulWidget {
  const PulsingSyncDot({super.key, this.color, this.size = 8.0});

  final Color? color;
  final double size;

  @override
  State<PulsingSyncDot> createState() => _PulsingSyncDotState();
}

class _PulsingSyncDotState extends State<PulsingSyncDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: _animation.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
