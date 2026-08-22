import '../../core/api_client.dart';
import '../../core/api_response.dart';
import 'models/formulir_lapangan.dart';

/// Repository Formulir Lapangan (docs/api-mobile.md §7).
/// Submit lewat outbox — lihat [FormulirController].
class FormulirRepository {
  FormulirRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Formulir hari ini; null bila belum diisi.
  Future<FormulirLapangan?> getHariIni() async {
    final res = await _api.get<FormulirLapangan?>(
      '/formulir/hari-ini',
      parse: (raw) => raw == null ? null : FormulirLapangan.fromJson(raw),
    );
    _ensureSuccess(res);
    return res.data;
  }

  /// Riwayat formulir dengan pagination.
  Future<RiwayatFormulirPage> getRiwayat({int page = 1}) async {
    final res = await _api.get<RiwayatFormulirPage>(
      '/formulir/riwayat',
      query: {'page': page},
      parse: RiwayatFormulirPage.fromJson,
    );
    _ensureSuccess(res);
    return res.data ??
        const RiwayatFormulirPage(items: [], currentPage: 1, lastPage: 1);
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}
