import 'package:flutter/material.dart';

class HeroTransition extends StatelessWidget {
  final String tag;
  final Widget child;
  final Widget placeholder;
  const HeroTransition({super.key, required this.tag, required this.child, required this.placeholder});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
        return Material(color: Colors.transparent, child: child);
      },
      child: child,
    );
  }
}
