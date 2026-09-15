import 'package:flutter/material.dart';

/// Staggered item entrance animation (Fade in + slide up by 12px).
/// Caps delay after [maxStaggerIndex] items for zero overhead on fast scrolling.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.delayStep = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 220),
    this.offsetY = 14.0,
    this.maxStaggerIndex = 8,
  });

  final Widget child;
  final int index;
  final Duration delayStep;
  final Duration duration;
  final double offsetY;
  final int maxStaggerIndex;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnimation = Tween<double>(
      begin: widget.offsetY,
      end: 0.0,
    ).animate(curved);

    final effectiveIndex = widget.index > widget.maxStaggerIndex
        ? widget.maxStaggerIndex
        : widget.index;
    final delay = widget.delayStep * effectiveIndex;

    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
