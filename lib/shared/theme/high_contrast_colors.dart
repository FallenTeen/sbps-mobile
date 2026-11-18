import 'package:flutter/material.dart';

/// High contrast color schemes for outdoor/accessibility mode.
///
/// Both schemes meet WCAG AA (4.5:1) for all text/icon combinations.
class HighContrastColors {
  HighContrastColors._();

  /// High contrast light scheme - saturated primary, darker surfaces.
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFB71C1C),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFFFCDD2),
    onPrimaryContainer: Color(0xFFB71C1C),
    secondary: Color(0xFF37474F),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFCFD8DC),
    onSecondaryContainer: Color(0xFF263238),
    tertiary: Color(0xFF1B5E20),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFC8E6C9),
    onTertiaryContainer: Color(0xFF1B5E20),
    error: Color(0xFFB71C1C),
    onError: Colors.white,
    errorContainer: Color(0xFFFFCDD2),
    onErrorContainer: Color(0xFFB71C1C),
    surface: Colors.white,
    onSurface: Colors.black,
    onSurfaceVariant: Colors.black87,
    outline: Colors.black54,
    outlineVariant: Colors.black38,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Colors.black,
    inversePrimary: Color(0xFFFFCDD2),
    surfaceTint: Color(0xFFB71C1C),
  );

  /// High contrast dark scheme - brighter surfaces, lighter primary.
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFCDD2),
    onPrimary: Colors.black,
    primaryContainer: Color(0xFFB71C1C),
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFFCFD8DC),
    onSecondary: Colors.black,
    secondaryContainer: Color(0xFF37474F),
    onSecondaryContainer: Colors.white,
    tertiary: Color(0xFFC8E6C9),
    onTertiary: Colors.black,
    tertiaryContainer: Color(0xFF1B5E20),
    onTertiaryContainer: Colors.white,
    error: Color(0xFFFFCDD2),
    onError: Colors.black,
    errorContainer: Color(0xFFB71C1C),
    onErrorContainer: Colors.white,
    surface: Color(0xFF121212),
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white70,
    outline: Colors.white54,
    outlineVariant: Colors.white38,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Colors.white,
    inversePrimary: Color(0xFFB71C1C),
    surfaceTint: Color(0xFFFFCDD2),
  );
}