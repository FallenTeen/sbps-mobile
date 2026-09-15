import '../../core/api_client.dart';
import '../../core/api_response.dart';

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

  /// Query versi app unified (param `app` selalu 'mobile').
  Future<AppVersionInfo> fetchAppVersion(String appName) async {
    final ApiResponse<Map<String, dynamic>> envelope = await _api.get(
      '/app-version',
      query: {'app': appName, 'platform': 'android'},
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );

    if (!envelope.isSuccess || envelope.data == null) {
      throw ApiException(
        envelope.message.isEmpty
            ? 'Gagal mengambil konfigurasi versi.'
            : envelope.message,
      );
    }

    return AppVersionInfo.fromJson(envelope.data!);
  }
}
