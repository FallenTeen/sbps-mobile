/// Konfigurasi aplikasi yang diinjeksi saat build via --dart-define-from-file.
///
/// Contoh: flutter run --flavor presensi \
///   --dart-define-from-file=env/presensi-staging.json
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/mobile',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'staging',
  );

  /// Nilai harus cocok dengan salah satu flavor Gradle:
  /// `presensi` atau `proyek`.
  static const String appFlavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'presensi',
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
