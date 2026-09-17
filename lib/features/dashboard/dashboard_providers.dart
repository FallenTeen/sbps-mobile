import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../qc/qc_providers.dart';
import 'dashboard_repository.dart';
import 'models.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(api: ref.watch(apiClientProvider)),
);

final overviewProvider = FutureProvider.autoDispose<DashboardOverview>(
  (ref) => ref.watch(dashboardRepositoryProvider).getOverview(),
);

final armadaStatusProvider = FutureProvider.autoDispose<ArmadaStatusData>(
  (ref) => ref.watch(dashboardRepositoryProvider).getArmadaStatus(),
);

final kehadiranDivisiProvider = FutureProvider.autoDispose<KehadiranDivisiData>(
  (ref) => ref.watch(dashboardRepositoryProvider).getKehadiranDivisi(),
);

/// Kunci periode chart: (bulan 1-12, tahun).
typedef ChartPeriod = ({int bulan, int tahun});

ChartPeriod currentPeriod() {
  final now = DateTime.now();
  return (bulan: now.month, tahun: now.year);
}

final produksiChartProvider = FutureProvider.autoDispose
    .family<ProduksiChart, ChartPeriod>(
      (ref, period) => ref
          .watch(dashboardRepositoryProvider)
          .getProduksiChart(bulan: period.bulan, tahun: period.tahun),
    );

final keuanganChartProvider = FutureProvider.autoDispose
    .family<KeuanganChart, ChartPeriod>(
      (ref, period) => ref
          .watch(dashboardRepositoryProvider)
          .getKeuanganChart(bulan: period.bulan, tahun: period.tahun),
    );

final poPendingProvider = FutureProvider.autoDispose<PoPendingPage>(
  (ref) => ref.watch(dashboardRepositoryProvider).getPoPending(),
);

final invoiceBelumDibayarProvider =
    FutureProvider.autoDispose<InvoicePendingPage>(
      (ref) => ref.watch(dashboardRepositoryProvider).getInvoiceBelumDibayar(),
    );

/// Sesi produksi selesai yang belum punya sampel QC (menunggu_hasil) — total
/// EXACT dari pagination server (1 halaman, tanpa muat seluruh antrian).
/// Dipakai kartu "Produksi Menunggu QC" di dashboard Mandor Titik.
final produksiMenungguQcProvider = FutureProvider.autoDispose<int>((ref) async {
  final page = await ref
      .watch(qcRepositoryProvider)
      .getRiwayat(status: 'menunggu_hasil', perPage: 50, page: 1);
  return page.total;
});

final titikDetailProvider = FutureProvider.autoDispose
    .family<TitikDetail, String>(
      (ref, titikId) =>
          ref.watch(dashboardRepositoryProvider).getTitikDetail(titikId),
    );

/// StateProvider periode chart aktif — dipakai layar dashboard & keuangan.
class ChartPeriodNotifier extends Notifier<ChartPeriod> {
  @override
  ChartPeriod build() => currentPeriod();

  void set(ChartPeriod period) => state = period;
}

final chartPeriodProvider = NotifierProvider<ChartPeriodNotifier, ChartPeriod>(
  ChartPeriodNotifier.new,
);

/// Helper role untuk menentukan section dashboard yang tampil.
DashboardSections dashboardSectionsFor(String? role) => DashboardSections(
  showOverview: RoleAccess.canSeeOverview(role),
  showArmadaStatus: RoleAccess.canSeeArmadaStatus(role),
  showKehadiran: RoleAccess.isAdminLike(role),
  showChartProduksi: RoleAccess.isAdminLike(role),
  showFinancial: RoleAccess.isAdminLike(role),
);

/// Akses section dashboard sisi client — UX saja, backend tetap 403.
class RoleAccess {
  const RoleAccess._();

  static bool isAdminLike(String? role) =>
      role == 'Owner' || role == 'Admin Keuangan';

  static bool canSeeOverview(String? role) =>
      isAdminLike(role) ||
      role == 'Mandor Titik' ||
      role == 'Kontraktor' ||
      role == 'Kepala Divisi Armada';

  /// Armada hanya untuk role yang punya modul armada (tap → /armada/overview).
  /// Mandor Titik TIDAK ditampilkan: kartu tanpa drill-down = dead-end.
  static bool canSeeArmadaStatus(String? role) =>
      isAdminLike(role) || role == 'Kepala Divisi Armada';
}

class DashboardSections {
  const DashboardSections({
    required this.showOverview,
    required this.showArmadaStatus,
    required this.showKehadiran,
    required this.showChartProduksi,
    required this.showFinancial,
  });

  final bool showOverview;
  final bool showArmadaStatus;
  final bool showKehadiran;
  final bool showChartProduksi;
  final bool showFinancial;
}
