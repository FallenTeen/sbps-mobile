import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'models/servis_armada.dart';
import 'servis_repository.dart';

final servisRepositoryProvider = Provider<ServisRepository>(
  (ref) => ServisRepository(
    api: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    sync: ref.watch(outboxSyncServiceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Master Armada Dropdown
// ---------------------------------------------------------------------------

final masterArmadaProvider = FutureProvider.autoDispose<List<MasterArmada>>((
  ref,
) {
  return ref.watch(servisRepositoryProvider).getMasterArmada();
});

// ---------------------------------------------------------------------------
// Riwayat Servis (Pagination + Filter Status)
// ---------------------------------------------------------------------------

class ServisRiwayatState {
  const ServisRiwayatState({
    this.items = const [],
    this.currentPage = 0,
    this.lastPage = 1,
    this.total = 0,
    this.loading = false,
    this.error,
    this.statusFilter,
  });

  final List<ServisArmada> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool loading;
  final String? error;
  final String? statusFilter;

  bool get hasMore => currentPage < lastPage;

  ServisRiwayatState copyWith({
    List<ServisArmada>? items,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? loading,
    String? error,
    String? statusFilter,
  }) => ServisRiwayatState(
    items: items ?? this.items,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    error: error,
    statusFilter: statusFilter ?? this.statusFilter,
  );
}

class ServisRiwayatController extends Notifier<ServisRiwayatState> {
  @override
  ServisRiwayatState build() {
    Future.microtask(() => _loadPage(page: 1));
    return const ServisRiwayatState(loading: true);
  }

  Future<void> _loadPage({required int page}) async {
    try {
      final result = await ref
          .read(servisRepositoryProvider)
          .getRiwayatServis(page: page, status: state.statusFilter);
      state = state.copyWith(
        items: page == 1 ? result.items : [...state.items, ...result.items],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        loading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Gagal memuat riwayat servis.',
      );
    }
  }

  Future<void> refresh() => _loadPage(page: 1);

  Future<void> filterByStatus(String? status) {
    state = state.copyWith(statusFilter: status, loading: true, items: []);
    return _loadPage(page: 1);
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    await _loadPage(page: state.currentPage + 1);
  }
}

final servisRiwayatProvider =
    NotifierProvider<ServisRiwayatController, ServisRiwayatState>(
      ServisRiwayatController.new,
    );

// ---------------------------------------------------------------------------
// Detail Servis Provider
// ---------------------------------------------------------------------------

final detailServisProvider = FutureProvider.autoDispose
    .family<ServisArmada, String>((ref, id) {
      return ref.watch(servisRepositoryProvider).getDetailServis(id);
    });

// ---------------------------------------------------------------------------
// Ringkasan Work Queue (total per status dari server)
// ---------------------------------------------------------------------------

/// Ringkasan jumlah servis per status — sumber angka work queue index.
/// Menggunakan endpoint riwayat yang sama dengan query `status` per bucket
/// (tidak mengarang endpoint status baru).
class ServisQueueSummary {
  const ServisQueueSummary({
    this.diajukan = 0,
    this.disetujui = 0,
    this.dikerjakan = 0,
    this.selesai = 0,
    this.ditolak = 0,
  });

  final int diajukan;
  final int disetujui;
  final int dikerjakan;
  final int selesai;
  final int ditolak;

  int countFor(String status) => switch (status) {
    'diajukan' => diajukan,
    'disetujui' => disetujui,
    'dikerjakan' => dikerjakan,
    'selesai' => selesai,
    'ditolak' => ditolak,
    _ => 0,
  };
}

final servisQueueSummaryProvider = FutureProvider.autoDispose<
  ServisQueueSummary
>((ref) async {
  final repo = ref.watch(servisRepositoryProvider);
  final results = await Future.wait([
    repo.getRiwayatServis(page: 1, status: 'diajukan'),
    repo.getRiwayatServis(page: 1, status: 'disetujui'),
    repo.getRiwayatServis(page: 1, status: 'dikerjakan'),
    repo.getRiwayatServis(page: 1, status: 'selesai'),
    repo.getRiwayatServis(page: 1, status: 'ditolak'),
  ]);
  return ServisQueueSummary(
    diajukan: results[0].total,
    disetujui: results[1].total,
    dikerjakan: results[2].total,
    selesai: results[3].total,
    ditolak: results[4].total,
  );
});

// ---------------------------------------------------------------------------
// Servis per unit armada (drill-down monitoring)
// ---------------------------------------------------------------------------

/// Riwayat servis milik satu unit armada.
///
/// Endpoint riwayat `/servis-armada` tidak menerima filter `armada_id`,
/// jadi ambil beberapa halaman lalu filter client-side. Batasi maksimal
/// [kMaxPages] halaman (±75 entri) — cukup untuk drill-down monitoring.
const int servisArmadaMaxPages = 5;

final servisArmadaUnitProvider = FutureProvider.autoDispose
    .family<List<ServisArmada>, String>((ref, armadaId) async {
      final repo = ref.watch(servisRepositoryProvider);
      final result = <ServisArmada>[];

      var page = await repo.getRiwayatServis(page: 1);
      result.addAll(page.items.where((s) => s.armadaId == armadaId));

      var current = page.currentPage;
      while (page.hasMore && current < servisArmadaMaxPages) {
        page = await repo.getRiwayatServis(page: current + 1);
        result.addAll(page.items.where((s) => s.armadaId == armadaId));
        current = page.currentPage;
      }
      return result;
    });
