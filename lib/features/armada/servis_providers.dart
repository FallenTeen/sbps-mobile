import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_providers.dart';
import 'models/servis_armada.dart';
import 'servis_repository.dart';

final servisRepositoryProvider = Provider<ServisRepository>(
  (ref) => ServisRepository(api: ref.watch(apiClientProvider)),
);

// ---------------------------------------------------------------------------
// Master Armada Dropdown
// ---------------------------------------------------------------------------

final masterArmadaProvider =
    FutureProvider.autoDispose<List<MasterArmada>>((ref) {
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
  }) =>
      ServisRiwayatState(
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
      final result = await ref.read(servisRepositoryProvider).getRiwayatServis(
            page: page,
            status: state.statusFilter,
          );
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
      state =
          state.copyWith(loading: false, error: 'Gagal memuat riwayat servis.');
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
        ServisRiwayatController.new);

// ---------------------------------------------------------------------------
// Detail Servis Provider
// ---------------------------------------------------------------------------

final detailServisProvider =
    FutureProvider.autoDispose.family<ServisArmada, String>((ref, id) {
  return ref.watch(servisRepositoryProvider).getDetailServis(id);
});
