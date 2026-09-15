import '../../core/api_client.dart';
import 'models/qc_sample.dart';

/// Repository Quality Control (docs/api-mobile.md §10).
/// Endpoint tulis (slump-test, uji-tekan) dijalankan via outbox dengan
/// `client_uuid` di body — lihat qc_providers.
class QcRepository {
  QcRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// GET /qc/riwayat?status=&per_page=&page=
  Future<QcRiwayatPage> getRiwayat({
    String? status,
    int perPage = 20,
    int page = 1,
  }) async {
    final res = await _api.get<QcRiwayatPage>(
      '/qc/riwayat',
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        'per_page': perPage,
        'page': page,
      },
      parse: QcRiwayatPage.fromRaw,
    );
    return res.data ??
        const QcRiwayatPage(items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  /// GET /qc/{id}
  Future<QcSample> getDetail(String id) async {
    final res = await _api.get<QcSample>(
      '/qc/$id',
      parse: (raw) => QcSample.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    return res.data!;
  }
}
