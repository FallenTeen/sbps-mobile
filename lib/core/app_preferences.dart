import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Preferensi aplikasi (Hive box `app_preferences`).
class AppPreferences {
  AppPreferences._();

  static const _kBox = 'app_preferences';
  static const _kThemeMode = 'theme_mode';
  static const _kHighContrastMode = 'ui.high_contrast_mode';
  static const _kOutdoorMode = 'ui.outdoor_mode';

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

  static Future<bool> getHighContrastMode() async {
    final box = await _openBox();
    return box.get(_kHighContrastMode) == 'true';
  }

  static Future<void> setHighContrastMode(bool value) async {
    final box = await _openBox();
    await box.put(_kHighContrastMode, value ? 'true' : 'false');
  }

  static Future<bool> getOutdoorMode() async {
    final box = await _openBox();
    return box.get(_kOutdoorMode) == 'true';
  }

  static Future<void> setOutdoorMode(bool value) async {
    final box = await _openBox();
    await box.put(_kOutdoorMode, value ? 'true' : 'false');
  }

  static Future<bool> getFlag(String key) async {
    final box = await _openBox();
    return box.get(key) == 'true';
  }

  static Future<void> setFlag(String key, bool value) async {
    final box = await _openBox();
    await box.put(key, value ? 'true' : 'false');
  }

  static Future<String?> getString(String key) async {
    final box = await _openBox();
    return box.get(key);
  }

  static Future<void> setString(String key, String value) async {
    final box = await _openBox();
    await box.put(key, value);
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

/// Mode kontras tinggi (outdoor/aksesibilitas). `false` = normal,
/// `true` = skema kontras tinggi. Baca-tulis Hive via [AppPreferences].
final highContrastModeProvider =
    AsyncNotifierProvider<HighContrastModeNotifier, bool>(
      HighContrastModeNotifier.new,
    );

class HighContrastModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => await AppPreferences.getHighContrastMode();

  Future<void> toggle() async {
    final value = !(state.value ?? false);
    await AppPreferences.setHighContrastMode(value);
    state = AsyncData(value);
  }
}

/// Mode luar ruangan: teks diperbesar agar terbaca di bawah matahari.
final outdoorModeProvider = AsyncNotifierProvider<OutdoorModeNotifier, bool>(
  OutdoorModeNotifier.new,
);

class OutdoorModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async => await AppPreferences.getOutdoorMode();

  Future<void> toggle() async {
    final value = !(state.value ?? false);
    await AppPreferences.setOutdoorMode(value);
    state = AsyncData(value);
  }
}
