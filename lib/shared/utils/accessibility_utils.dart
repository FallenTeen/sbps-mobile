import 'dart:math' as math;
import 'package:flutter/material.dart';

Widget semanticButton({required Widget child, required String label, String? hint}) {
  return Semantics(button: true, label: label, hint: hint, child: child);
}

Widget semanticIconButton({required IconData icon, required String label, VoidCallback? onTap}) {
  return Semantics(
    button: true,
    label: label,
    child: IconButton(icon: Icon(icon), onPressed: onTap, tooltip: label),
  );
}

bool meetsContrastAA(Color foreground, Color background) {
  return _contrastRatio(foreground, background) >= 4.5;
}

bool meetsContrastAAA(Color foreground, Color background) {
  return _contrastRatio(foreground, background) >= 7.0;
}

double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

Widget wrapFocusGroup({required Widget child}) {
  return FocusTraversalGroup(child: child);
}

FocusNode createFocusNode({String? debugLabel}) {
  return FocusNode(debugLabel: debugLabel);
}
