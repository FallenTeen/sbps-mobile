import 'package:flutter/material.dart';

/// Spacing scale tokens for consistent layout rhythm.
///
/// Base unit = 16dp (md). All values are multiples of 4dp.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static final EdgeInsets paddingXs = EdgeInsets.all(xs);
  static final EdgeInsets paddingSm = EdgeInsets.all(sm);
  static final EdgeInsets paddingMd = EdgeInsets.all(md);
  static final EdgeInsets paddingLg = EdgeInsets.all(lg);
  static final EdgeInsets paddingXl = EdgeInsets.all(xl);

  static final EdgeInsets horizontalXs = EdgeInsets.symmetric(horizontal: xs);
  static final EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static final EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static final EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static final EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  static final EdgeInsets verticalXs = EdgeInsets.symmetric(vertical: xs);
  static final EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static final EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static final EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  static final EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  static final EdgeInsets onlyBottomXs = EdgeInsets.only(bottom: xs);
  static final EdgeInsets onlyBottomSm = EdgeInsets.only(bottom: sm);
  static final EdgeInsets onlyBottomMd = EdgeInsets.only(bottom: md);
  static final EdgeInsets onlyBottomLg = EdgeInsets.only(bottom: lg);
  static final EdgeInsets onlyBottomXl = EdgeInsets.only(bottom: xl);
  static final EdgeInsets onlyBottomXxl = EdgeInsets.only(bottom: xxl);

  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  static const SizedBox hGapXs = SizedBox(width: xs);
  static const SizedBox hGapSm = SizedBox(width: sm);
  static const SizedBox hGapMd = SizedBox(width: md);
  static const SizedBox hGapLg = SizedBox(width: lg);
  static const SizedBox hGapXl = SizedBox(width: xl);
  static const SizedBox hGapXxl = SizedBox(width: xxl);

  static const SizedBox vGapXs = SizedBox(height: xs);
  static const SizedBox vGapSm = SizedBox(height: sm);
  static const SizedBox vGapMd = SizedBox(height: md);
  static const SizedBox vGapLg = SizedBox(height: lg);
  static const SizedBox vGapXl = SizedBox(height: xl);
  static const SizedBox vGapXxl = SizedBox(height: xxl);
}

