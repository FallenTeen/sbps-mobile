import '../../core/api_client.dart';
import '../../core/api_response.dart';
import 'inventory_models.dart';

/// Repository modul Inventory — Stok & Sparepart (Section 14d / Bagian 21.7).
/// Mengelola ringkasan, daftar stok bahan baku & sparepart, request sparepart
/// dari workshop, dan checklist stok opname.
class InventoryRepository {
  InventoryRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// GET /inventory/summary — ringkasan jumlah item, nilai stok, item yang
  /// di bawah minimum, dan request sparepart pending.
  Future<InventorySummary> getSummary() async {
    final res = await _api.get<InventorySummary>(
      '/inventory/summary',
      parse: (raw) {
        final map = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        return InventorySummary.fromJson(map);
      },
    );
    _ensureSuccess(res);
    return res.data!;
  }

  /// GET /inventory/materials?kategori= — daftar stok dengan saldo saat ini.
  Future<List<InventoryItem>> getStok({String? kategori}) async {
    final res = await _api.get<List<InventoryItem>>(
      '/inventory/materials',
      query: {'kategori': ?kategori},
      parse: (raw) {
        return <InventoryItem>[
          if (raw is List)
            for (final e in raw)
              if (e is Map)
                InventoryItem.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  /// GET /inventory/requests?status= — request sparepart dari workshop.
  Future<List<InventoryRequest>> getRequests({String? status}) async {
    final res = await _api.get<List<InventoryRequest>>(
      '/inventory/requests',
      query: {'status': ?status},
      parse: (raw) {
        return <InventoryRequest>[
          if (raw is List)
            for (final e in raw)
              if (e is Map)
                InventoryRequest.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  /// GET /inventory/requests/{id} — detail satu request sparepart.
  Future<InventoryRequest> getRequestDetail(String id) async {
    final res = await _api.get<InventoryRequest>(
      '/inventory/requests/$id',
      parse: (raw) =>
          InventoryRequest.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    _ensureSuccess(res);
    return res.data!;
  }

  /// POST /inventory/requests/{id}/proses — tandai item yang dikirim jadi
  /// tersedia (nominal/jumlah lama dipertahankan saat hanya id yang dikirim).
  Future<void> prosesRequest({
    required String id,
    required List<String> itemIds,
  }) async {
    final res = await _api.post<Object?>(
      '/inventory/requests/$id/proses',
      body: {
        'items': [
          for (final itemId in itemIds) {'id': itemId},
        ],
      },
    );
    _ensureSuccess(res);
  }

  /// GET /inventory/opname/materials — item untuk form stok opname.
  Future<List<OpnameItem>> getOpnameMaterials() async {
    final res = await _api.get<List<OpnameItem>>(
      '/inventory/opname/materials',
      parse: (raw) {
        return <OpnameItem>[
          if (raw is List)
            for (final e in raw)
              if (e is Map) OpnameItem.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  /// GET /inventory/mutasi?kategori=&bahan_baku_id=&tanggal_mulai=&tanggal_akhir=&per_page=&page=
  /// Riwayat mutasi lintas semua barang.
  Future<StokMutasiPage> getMutasi({
    String? kategori,
    String? bahanBakuId,
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
    int perPage = 20,
    int page = 1,
  }) async {
    final res = await _api.get<StokMutasiPage>(
      '/inventory/mutasi',
      query: {
        if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
        if (bahanBakuId != null && bahanBakuId.isNotEmpty)
          'bahan_baku_id': bahanBakuId,
        if (tanggalMulai != null)
          'tanggal_mulai': _isoDate(tanggalMulai),
        if (tanggalAkhir != null) 'tanggal_akhir': _isoDate(tanggalAkhir),
        'per_page': perPage,
        'page': page,
      },
      parse: StokMutasiPage.fromRaw,
    );
    return res.data ??
        const StokMutasiPage(items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  /// GET /inventory/materials/{id}/mutasi — riwayat mutasi khusus 1 barang.
  Future<StokMutasiPage> getMaterialMutasi(
    String id, {
    DateTime? tanggalMulai,
    DateTime? tanggalAkhir,
    int perPage = 20,
    int page = 1,
  }) async {
    final res = await _api.get<StokMutasiPage>(
      '/inventory/materials/$id/mutasi',
      query: {
        if (tanggalMulai != null) 'tanggal_mulai': _isoDate(tanggalMulai),
        if (tanggalAkhir != null) 'tanggal_akhir': _isoDate(tanggalAkhir),
        'per_page': perPage,
        'page': page,
      },
      parse: StokMutasiPage.fromRaw,
    );
    return res.data ??
        const StokMutasiPage(items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
