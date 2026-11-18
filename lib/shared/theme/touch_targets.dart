import 'package:flutter/material.dart';

/// Touch target constants for accessibility and usability.
///
/// Minimum 48dp (Material baseline), comfortable 56dp (glove-friendly),
/// hero 64dp (primary actions like FAB, sticky bar).
abstract class TouchTargets {
  static const double minTap = 48.0;
  static const double comfortable = 56.0;
  static const double hero = 64.0;

  static const double iconSmall = 20;
  static const double iconMedium = 24;
  static const double iconLarge = 32;
  static const double iconHero = 36;

  static double buttonMinHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.shortestSide < 600) return minTap;
    return comfortable;
  }
}

