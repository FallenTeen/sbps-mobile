import '../../core/api_client.dart';
import '../../core/api_response.dart';
import 'models/kontraktor_models.dart';

/// Repository Portal Kontraktor (§14 API Mobile).
/// Mengelola daftar proyek kontrak klien, detail progress & RAB agregat,
/// daftar invoice, dan log komunikasi dua arah antara kontraktor dan kantor.
class KontraktorRepository {
  KontraktorRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// GET /kontraktor/proyek — Daftar proyek kontrak klien.
  Future<List<ProyekKontrakItem>> getProyekList() async {
    final res = await _api.get<List<ProyekKontrakItem>>(
      '/kontraktor/proyek',
      parse: (raw) {
        final items = raw is List
            ? raw
            : (raw is Map
                  ? (raw['items'] ?? raw['data'] ?? const [])
                  : const []);
        return <ProyekKontrakItem>[
          if (items is List)
            for (final e in items)
              if (e is Map)
                ProyekKontrakItem.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  /// GET /kontraktor/proyek/{id} — Detail proyek kontrak (progress produksi, RAB, invoice, chat).
  Future<DetailProyekKontrak> getProyekDetail(String id) async {
    final res = await _api.get<DetailProyekKontrak>(
      '/kontraktor/proyek/$id',
      parse: (raw) =>
          DetailProyekKontrak.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    _ensureSuccess(res);
    return res.data!;
  }

  /// GET /kontraktor/invoice — Daftar seluruh invoice proyek kontrak.
  Future<List<InvoiceKontrakItem>> getInvoiceList() async {
    final res = await _api.get<List<InvoiceKontrakItem>>(
      '/kontraktor/invoice',
      parse: (raw) {
        final items = raw is List
            ? raw
            : (raw is Map
                  ? (raw['items'] ?? raw['data'] ?? const [])
                  : const []);
        return <InvoiceKontrakItem>[
          if (items is List)
            for (final e in items)
              if (e is Map)
                InvoiceKontrakItem.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  /// POST /kontraktor/komunikasi — Kirim pesan komunikasi pada proyek kontrak.
  Future<KomunikasiLogItem> sendMessage({
    required String proyekId,
    required String pesan,
  }) async {
    final res = await _api.post<KomunikasiLogItem>(
      '/kontraktor/komunikasi',
      body: {'proyek_id': proyekId, 'pesan': pesan},
      parse: (raw) =>
          KomunikasiLogItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    _ensureSuccess(res);
    return res.data!;
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}
