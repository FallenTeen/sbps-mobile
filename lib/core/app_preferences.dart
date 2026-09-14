import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Preferensi aplikasi yang disimpan lokal di Hive box `app_preferences`
/// (Rencana Pengembangan UX §Bagian 2 — D5).
class AppPreferences {
  AppPreferences._();

  static const _kBox = 'app_preferences';
  static const _kThemeMode = 'theme_mode';

  static Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_kBox)) return Hive.box<String>(_kBox);
    return Hive.openBox<String>(_kBox);
  }

  static Future<ThemeMode?> loadThemeMode() async {
    final box = await _openBox();
    final saved = box.get(_kThemeMode);
    if (saved == null) return null;
    for (final mode in ThemeMode.values) {
      if (mode.name == saved) return mode;
    }
    return null;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final box = await _openBox();
    await box.put(_kThemeMode, mode.name);
  }
}

/// Tema aktif user: `light` (default, perilaku sekarang), `dark`, atau
/// `system`. Baca-tulis Hive via [AppPreferences].
final themeModeProvider = AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async =>
      (await AppPreferences.loadThemeMode()) ?? ThemeMode.light;

  Future<void> select(ThemeMode mode) async {
    await AppPreferences.saveThemeMode(mode);
    state = AsyncData(mode);
  }
}