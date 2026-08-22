import '../../core/api_client.dart';

/// Model ringkas dari GET /api/mobile/app-version
/// (lihat docs/api-mobile.md bagian 5.7).
class AppVersionInfo {
  const AppVersionInfo({
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.updateUrl,
    required this.changelog,
  });

  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String updateUrl;
  final String? changelog;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        minVersion: json['min_version'] as String? ?? '',
        latestVersion: json['latest_version'] as String? ?? '',
        forceUpdate: json['force_update'] == true,
        updateUrl: json['update_url'] as String? ?? '',
        changelog: json['changelog'] as String?,
      );
}

class VersionService {
  VersionService({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// `app` diambil dari flavor aktif: presensi / proyek.
  Future<AppVersionInfo> fetchAppVersion() async {
    final envelope = await _api.getJson(
      '/app-version?app=${Uri.encodeComponent(_appName())}&platform=android',
    );

    if (envelope['status'] != 'success') {
      throw ApiException('Gagal mengambil konfigurasi versi.');
    }

    return AppVersionInfo.fromJson(
      (envelope['data'] ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  static String _appName() {
    switch (_flavor) {
      case 'proyek':
        return 'proyek';
      default:
        return 'presensi';
    }
  }

  static const String _flavor = String.fromEnvironment('APP_FLAVOR');
}
