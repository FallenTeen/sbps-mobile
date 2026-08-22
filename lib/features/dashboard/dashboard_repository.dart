import '../../core/api_client.dart';
import 'models.dart';

/// Repository Dashboard & Chart (docs/api-mobile.md §12).
/// Semua endpoint GET + auth; akses finansial divalidasi backend (403).
class DashboardRepository {
  DashboardRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// GET /dashboard/overview
  Future<DashboardOverview> getOverview() async {
    final res = await _api.get<DashboardOverview>(
      '/dashboard/overview',
      parse: DashboardOverview.fromRaw,
    );
    return res.data ??
        const DashboardOverview(tanggal: '', totalTitik: 0, items: []);
  }

  /// GET /dashboard/titik/{titikId}
  Future<TitikDetail> getTitikDetail(String titikId) async {
    final res = await _api.get<TitikDetail>(
      '/dashboard/titik/$titikId',
      parse: TitikDetail.fromRaw,
    );
    return res.data!;
  }

  /// GET /dashboard/chart/produksi?bulan=&tahun=
  Future<ProduksiChart> getProduksiChart({int? bulan, int? tahun}) async {
    final res = await _api.get<ProduksiChart>(
      '/dashboard/chart/produksi',
      query: {
        'bulan': ?bulan,
        'tahun': ?tahun,
      },
      parse: (raw) => ProduksiChart.fromRaw(raw, bulan: bulan, tahun: tahun),
    );
    return res.data ?? ProduksiChart(bulan: bulan ?? 1, tahun: tahun ?? 1, items: const []);
  }

  /// GET /dashboard/chart/keuangan?bulan=&tahun= — Owner/Admin Keuangan.
  Future<KeuanganChart> getKeuanganChart({int? bulan, int? tahun}) async {
    final res = await _api.get<KeuanganChart>(
      '/dashboard/chart/keuangan',
      query: {
        'bulan': ?bulan,
        'tahun': ?tahun,
      },
      parse: (raw) => KeuanganChart.fromRaw(raw, bulan: bulan, tahun: tahun),
    );
    return res.data ??
        KeuanganChart(bulan: bulan ?? 1, tahun: tahun ?? 1, items: const []);
  }

  /// GET /dashboard/armada-status
  Future<ArmadaStatusData> getArmadaStatus() async {
    final res = await _api.get<ArmadaStatusData>(
      '/dashboard/armada-status',
      parse: ArmadaStatusData.fromRaw,
    );
    return res.data ?? const ArmadaStatusData(total: 0, items: []);
  }

  /// GET /dashboard/kehadiran-divisi — Owner/Admin.
  Future<KehadiranDivisiData> getKehadiranDivisi() async {
    final res = await _api.get<KehadiranDivisiData>(
      '/dashboard/kehadiran-divisi',
      parse: KehadiranDivisiData.fromRaw,
    );
    return res.data ??
        const KehadiranDivisiData(
            tanggal: '', totalHadir: 0, items: []);
  }

  /// GET /dashboard/po-pending — Owner/Admin Keuangan. Server maks 20 item.
  Future<PoPendingPage> getPoPending() async {
    final res = await _api.get<PoPendingPage>(
      '/dashboard/po-pending',
      parse: PoPendingPage.fromRaw,
    );
    return res.data ?? const PoPendingPage(total: 0, items: []);
  }

  /// GET /dashboard/invoice-belum-dibayar — Owner/Admin Keuangan. Maks 20 item.
  Future<InvoicePendingPage> getInvoiceBelumDibayar() async {
    final res = await _api.get<InvoicePendingPage>(
      '/dashboard/invoice-belum-dibayar',
      parse: InvoicePendingPage.fromRaw,
    );
    return res.data ?? const InvoicePendingPage(total: 0, items: []);
  }
}
