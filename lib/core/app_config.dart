/// Konfigurasi aplikasi yang diinjeksi saat build via --dart-define-from-file.
///
/// Contoh: flutter run --dart-define-from-file=env/staging.json
class AppConfig {
  const AppConfig._();

  /// Wajib diisi lewat --dart-define-from-file; tanpa default.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get requiredApiBaseUrl {
    assert(apiBaseUrl.isNotEmpty, 'API_BASE_URL wajib diisi via --dart-define-from-file');
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL tidak diset. Build harus memakai '
        '--dart-define-from-file=env/<env>.json (contoh: env/staging.json).',
      );
    }
    return apiBaseUrl;
  }

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'staging',
  );

  static bool get isProduction => appEnv == 'production';

  /// Kosong berarti Sentry belum dikonfigurasi (diisi di env production).
  static const String sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  /// Jam cutoff tracking harian (lokal). Titik dengan timestamp >= jam ini
  /// tidak dikumpulkan/dikirim; backend juga menolak menyimpannya.
  static const int trackingCutoffHour = int.fromEnvironment(
    'TRACKING_CUTOFF_HOUR',
    defaultValue: 18,
  );
}
