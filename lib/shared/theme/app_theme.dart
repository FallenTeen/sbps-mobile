import 'package:flutter/material.dart';

/// Custom theme for SBPS Mobile Apps.
///
/// Provides a polished, professional look with consistent design tokens
/// across all screens. Uses a brick-red primary palette (Fase C0 UX plan)
/// with indigo & amber accents.
class AppTheme {
  AppTheme._();

  // ── Color Palette ──────────────────────────────────────────────────────────
  // Rencana Pengembangan UX Fase C0: primer teal → "brick red" (#DC2626).
  // Secondary tetap indigo & tertiary tetap amber (kontras cukup dengan merah).
  // Error digeser ke merah tua (#B91C1C) agar tidak "sama" dengan primary
  // (dikombinasikan ikon ⚠ untuk status error, bukan hanya warna).
  static const Color _primary = Color(0xFFDC2626);
  static const Color _primaryLight = Color(0xFFFCA5A5);
  static const Color _primaryDark = Color(0xFF991B1B);
  static const Color _secondary = Color(0xFF6366F1);
  static const Color _tertiary = Color(0xFFF59E0B);
  static const Color _surface = Color(0xFFFAFBFC);
  static const Color _surfaceVariant = Color(0xFFF1F5F9);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _error = Color(0xFFB91C1C);
  static const Color _success = Color(0xFF10B981);
  static const Color _warning = Color(0xFFF59E0B);

  // ── Brand Gradient ─────────────────────────────────────────────────────────
  /// Gradien identitas SBPS (Fase C0/C5): dipakai di splash, header ringkasan,
  /// AppBar modul utama, portal, dan badge "terdekat". Ganti di sini cukup
  /// untuk mengubah semua header gradient sekaligus.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Elevation & Depth (Fase C1) ────────────────────────────────────────────
  // Tingkat shadow bertingkat untuk membedakan kedalaman visual:
  // Lv1 = kartu list biasa (flat), Lv2 = kartu penting/interaktif,
  // Lv3 = header/ringkasan & element mengambang.
  static const List<BoxShadow> shadowLv1 = [
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowLv2 = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowLv3 = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // ── Light Color Scheme ─────────────────────────────────────────────────────
  static final ColorScheme _lightColorScheme = ColorScheme.light(
    primary: _primary,
    onPrimary: Colors.white,
    primaryContainer: _primaryLight.withValues(alpha: 0.3),
    onPrimaryContainer: _primaryDark,
    secondary: _secondary,
    onSecondary: Colors.white,
    secondaryContainer: _secondary.withValues(alpha: 0.1),
    onSecondaryContainer: _secondary,
    tertiary: _tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: _tertiary.withValues(alpha: 0.1),
    onTertiaryContainer: _tertiary,
    surface: _surface,
    onSurface: const Color(0xFF1E293B),
    onSurfaceVariant: const Color(0xFF64748B),
    error: _error,
    onError: Colors.white,
    outline: const Color(0xFFCBD5E1),
    outlineVariant: const Color(0xFFE2E8F0),
    shadow: const Color(0xFF000000),
  );

  // ── Text Theme ─────────────────────────────────────────────────────────────
  static final TextTheme _textTheme = TextTheme(
    displayLarge: const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      color: Color(0xFF0F172A),
    ),
    displayMedium: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: Color(0xFF0F172A),
    ),
    headlineLarge: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: Color(0xFF0F172A),
    ),
    headlineMedium: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E293B),
    ),
    headlineSmall: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E293B),
    ),
    titleLarge: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E293B),
    ),
    titleMedium: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Color(0xFF334155),
    ),
    titleSmall: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Color(0xFF475569),
    ),
    bodyLarge: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: Color(0xFF334155),
      height: 1.5,
    ),
    bodyMedium: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: Color(0xFF475569),
      height: 1.4,
    ),
    bodySmall: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Color(0xFF64748B),
      height: 1.3,
    ),
    labelLarge: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: Color(0xFF475569),
    ),
    labelMedium: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
      color: Color(0xFF64748B),
    ),
    labelSmall: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      color: Color(0xFF94A3B8),
    ),
  );

  // ── Card Theme ─────────────────────────────────────────────────────────────
  static final CardThemeData _cardTheme = CardThemeData(
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    color: Colors.white,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
  );

  // ── AppBar Theme ───────────────────────────────────────────────────────────
  static final AppBarTheme _appBarTheme = AppBarTheme(
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    backgroundColor: _background,
    foregroundColor: const Color(0xFF0F172A),
    titleTextStyle: const TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: Color(0xFF0F172A),
      letterSpacing: -0.3,
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFF475569),
      size: 22,
    ),
    actionsIconTheme: const IconThemeData(
      color: Color(0xFF475569),
      size: 22,
    ),
  );

  // ── Input Decoration Theme ─────────────────────────────────────────────────
  static final InputDecorationTheme _inputTheme = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _error),
    ),
    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
  );

  // ── Button Themes ──────────────────────────────────────────────────────────
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
  );

  static final FilledButtonThemeData _filledButtonTheme = FilledButtonThemeData(
    style: FilledButton.styleFrom(
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      foregroundColor: const Color(0xFF475569),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _primary,
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  // ── Chip Theme ─────────────────────────────────────────────────────────────
  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: _surfaceVariant,
    selectedColor: _primary.withValues(alpha: 0.15),
    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );

  // ── Bottom Sheet Theme ─────────────────────────────────────────────────────
  static final BottomSheetThemeData _bottomSheetTheme = BottomSheetThemeData(
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    showDragHandle: true,
    dragHandleColor: const Color(0xFFCBD5E1),
  );

  // ── Dialog Theme ───────────────────────────────────────────────────────────
  static final DialogThemeData _dialogTheme = DialogThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: Colors.white,
    elevation: 8,
  );

  // ── Snackbar Theme ─────────────────────────────────────────────────────────
  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    backgroundColor: const Color(0xFF1E293B),
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    behavior: SnackBarBehavior.floating,
  );

  // ── Main ThemeData ─────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      textTheme: _textTheme,
      scaffoldBackgroundColor: _background,
      cardTheme: _cardTheme,
      appBarTheme: _appBarTheme,
      inputDecorationTheme: _inputTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      filledButtonTheme: _filledButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      chipTheme: _chipTheme,
      bottomSheetTheme: _bottomSheetTheme,
      dialogTheme: _dialogTheme,
      snackBarTheme: _snackBarTheme,
      splashColor: _primary.withValues(alpha: 0.08),
      highlightColor: _primary.withValues(alpha: 0.04),
      dividerColor: const Color(0xFFE2E8F0),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ── Design Tokens (for inline use) ─────────────────────────────────────────
  static const Color primaryColor = _primary;
  static const Color secondaryColor = _secondary;
  static const Color tertiaryColor = _tertiary;
  static const Color surfaceColor = _surface;
  static const Color surfaceVariantColor = _surfaceVariant;
  static const Color backgroundColor = _background;
  static const Color errorColor = _error;
  static const Color successColor = _success;
  static const Color warningColor = _warning;
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE2E8F0);
  static const Color cardColor = Colors.white;
}
