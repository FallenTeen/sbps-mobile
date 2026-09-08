import 'package:flutter/material.dart';

/// Breakpoint standar Material 3 untuk responsivitas layout:
/// - Compact: Phone (< 600dp)
/// - Medium: Tablet portrait / Foldable (600 - 839dp)
/// - Expanded: Tablet landscape / Large display (>= 840dp)
class AppBreakpoints {
  AppBreakpoints._();

  static const double compactMax = 599.0;
  static const double mediumMin = 600.0;
  static const double mediumMax = 839.0;
  static const double expandedMin = 840.0;

  /// Max width untuk form agar tidak melar di tablet
  static const double maxFormWidth = 640.0;

  /// Max width untuk content card di tablet landscape
  static const double maxContentWidth = 960.0;
}

enum ScreenClass { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  Orientation get orientation => MediaQuery.orientationOf(this);
  bool get isLandscape => orientation == Orientation.landscape;

  ScreenClass get screenClass {
    final width = screenWidth;
    if (width >= AppBreakpoints.expandedMin) return ScreenClass.expanded;
    if (width >= AppBreakpoints.mediumMin) return ScreenClass.medium;
    return ScreenClass.compact;
  }

  bool get isCompact => screenClass == ScreenClass.compact;
  bool get isMedium => screenClass == ScreenClass.medium;
  bool get isExpanded => screenClass == ScreenClass.expanded;
  bool get isTablet => screenWidth >= AppBreakpoints.mediumMin;

  /// Helper untuk memilih nilai sesuai kelas ukuran layar
  T responsiveValue<T>({
    required T compact,
    T? medium,
    T? expanded,
  }) {
    switch (screenClass) {
      case ScreenClass.expanded:
        return expanded ?? medium ?? compact;
      case ScreenClass.medium:
        return medium ?? compact;
      case ScreenClass.compact:
        return compact;
    }
  }
}

/// Container yang membatasi lebar form / konten di layar lebar (Tablet)
/// dan menaruhnya tepat di tengah (Centered).
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxFormWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return content;
  }
}
