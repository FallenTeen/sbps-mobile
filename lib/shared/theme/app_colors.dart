import 'package:flutter/material.dart';

/// Tema-warna aplikasi SBPS sebagai `ThemeExtension`.
///
/// Dipakai untuk semua warna inline yang dulu memakai konstanta statis
/// `AppTheme.*` (mis. `context.colors.textPrimary`) — supaya warnanya otomatis
/// mengikuti mode terang/gelap tanpa perlu cabang `if (isDark)`. Diakses
/// lewat `context.colors.*` (ekstensi `AppThemeContext`).
///
/// Dua instansi: `AppColors.light` (identik dengan konstanta lama) dan
/// `AppColors.dark` (palet gelap — Rencana Pengembangan UX §Bagian 2).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.info,
    required this.success,
    required this.warning,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.chartPositive,
    required this.chartNegative,
    required this.chartGridLine,
    required this.chartBarPrimary,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color border;
  final Color primary;
  final Color secondary;
  final Color info;
  final Color success;
  final Color warning;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textMuted;

  /// Warna data positif chart (masuk/pass-rate) — kontras AA di atas card.
  final Color chartPositive;

  /// Warna data negatif chart (keluar/gagal) — kontras AA di atas card.
  final Color chartNegative;

  /// Garis grid chart — terlihat baik di mode terang maupun gelap.
  final Color chartGridLine;

  /// Warna batang primer chart (mis. chart produksi).
  final Color chartBarPrimary;

  static const light = AppColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFAFBFC),
    surfaceVariant: Color(0xFFF1F5F9),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE2E8F0),
    primary: Color(0xFFDC2626),
    secondary: Color(0xFF6366F1),
    info: Color(0xFF3B82F6),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFB91C1C),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    chartPositive: Color(0xFF059669),
    chartNegative: Color(0xFFDC2626),
    chartGridLine: Color(0xFFE2E8F0),
    chartBarPrimary: Color(0xFFDC2626),
  );

  /// Palet gelap (M3 dark): surface mendekati hitam, teks terang.
  /// Primary/gelap dicerahkan (tone 80) agar kontras AA di atas surface
  /// gelap (Rencana §2.2 D1).
  static const dark = AppColors(
    background: Color(0xFF0F1115),
    surface: Color(0xFF1A1D23),
    surfaceVariant: Color(0xFF23272F),
    card: Color(0xFF1E2228),
    border: Color(0xFF2E3440),
    primary: Color(0xFFF87171),
    secondary: Color(0xFFA5B4FC),
    info: Color(0xFF60A5FA),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF28B82),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFC7CDD8),
    textTertiary: Color(0xFF9AA3B2),
    textMuted: Color(0xFF6B7280),
    chartPositive: Color(0xFF4ADE80),
    chartNegative: Color(0xFFF87171),
    chartGridLine: Color(0xFF3B4252),
    chartBarPrimary: Color(0xFFF87171),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? card,
    Color? border,
    Color? primary,
    Color? secondary,
    Color? info,
    Color? success,
    Color? warning,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textMuted,
    Color? chartPositive,
    Color? chartNegative,
    Color? chartGridLine,
    Color? chartBarPrimary,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      info: info ?? this.info,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textMuted: textMuted ?? this.textMuted,
      chartPositive: chartPositive ?? this.chartPositive,
      chartNegative: chartNegative ?? this.chartNegative,
      chartGridLine: chartGridLine ?? this.chartGridLine,
      chartBarPrimary: chartBarPrimary ?? this.chartBarPrimary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      info: Color.lerp(info, other.info, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      chartPositive: Color.lerp(chartPositive, other.chartPositive, t)!,
      chartNegative: Color.lerp(chartNegative, other.chartNegative, t)!,
      chartGridLine: Color.lerp(chartGridLine, other.chartGridLine, t)!,
      chartBarPrimary: Color.lerp(chartBarPrimary, other.chartBarPrimary, t)!,
    );
  }
}

/// Akses cepat warna tema: `context.colors.primary`.
extension AppThemeContext on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
