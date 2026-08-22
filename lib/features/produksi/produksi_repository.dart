import '../../core/api_client.dart';
import 'models/master.dart';
import 'models/production_session.dart';

/// Repository Laporan Produksi Harian (docs/api-mobile.md §8) + master
/// data §8.6. Endpoint tulis memakai `client_uuid` di BODY (bukan header
/// Idempotency-Key) — dijalankan via outbox agar tahan offline.
class ProduksiRepository {
  ProduksiRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<List<MesinMaster>> getMesin() async {
    final res = await _api.get<List<MesinMaster>>(
      '/master/mesin',
      parse: (raw) => [
        if (raw is List)
          for (final e in raw) MesinMaster.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
    return res.data ?? const [];
  }

  Future<List<ProdukMaster>> getProduk() async {
    final res = await _api.get<List<ProdukMaster>>(
      '/master/produk',
      parse: (raw) => [
        if (raw is List)
          for (final e in raw) ProdukMaster.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
    return res.data ?? const [];
  }

  Future<List<BahanBakuMaster>> getBahanBaku() async {
    final res = await _api.get<List<BahanBakuMaster>>(
      '/master/bahan-baku',
      parse: (raw) => [
        if (raw is List)
          for (final e in raw)
            BahanBakuMaster.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
    return res.data ?? const [];
  }

  /// GET /produksi/sesi-aktif — daftar sesi berstatus berjalan.
  Future<List<ProductionSession>> getSesiAktif() async {
    final res = await _api.get<List<ProductionSession>>(
      '/produksi/sesi-aktif',
      parse: (raw) => [
        if (raw is List)
          for (final e in raw)
            ProductionSession.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
    return res.data ?? const [];
  }

  /// GET /produksi/riwayat?tanggal=&mesin_id=&page=
  Future<ProduksiRiwayatPage> getRiwayat({
    String? tanggal,
    String? mesinId,
    int page = 1,
  }) async {
    final res = await _api.get<ProduksiRiwayatPage>(
      '/produksi/riwayat',
      query: {
        if (tanggal != null && tanggal.isNotEmpty) 'tanggal': tanggal,
        if (mesinId != null && mesinId.isNotEmpty) 'mesin_id': mesinId,
        'page': page,
      },
      parse: ProduksiRiwayatPage.fromRaw,
    );
    return res.data ??
        const ProduksiRiwayatPage(
            items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  /// GET /produksi/titik-progress — ringkasan output per titik hari ini.
  Future<(String, List<TitikProgressItem>)> getTitikProgress() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/produksi/titik-progress',
      parse: (raw) => raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
    final data = res.data ?? const {};
    return (
      data['tanggal']?.toString() ?? '',
      [
        if (data['items'] is List)
          for (final e in data['items'] as List)
            TitikProgressItem.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}
