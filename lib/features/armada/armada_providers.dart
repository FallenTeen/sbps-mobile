import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'armada_repository.dart';
import 'models/armada.dart';
import 'models/helper.dart';

final armadaRepositoryProvider = Provider<ArmadaRepository>(
  (ref) => ArmadaRepository(
    api: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    sync: ref.watch(outboxSyncServiceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Armada saya (kendaraan driver)
// ---------------------------------------------------------------------------

final armadaSayaProvider = FutureProvider.autoDispose<List<ArmadaSaya>>((ref) {
  return ref.watch(armadaRepositoryProvider).getArmadaSaya();
});

// ---------------------------------------------------------------------------
// Checklist harian armada
// ---------------------------------------------------------------------------

final checklistHariIniProvider =
    FutureProvider.autoDispose<List<ArmadaChecklist>>((ref) {
      return ref.watch(armadaRepositoryProvider).getChecklistHariIni();
    });

// ---------------------------------------------------------------------------
// Riwayat ritase (pagination)
// ---------------------------------------------------------------------------

class RitaseRiwayatState {
  const RitaseRiwayatState({
    this.items = const [],
    this.currentPage = 0,
    this.lastPage = 1,
    this.total = 0,
    this.loading = false,
    this.error,
  });

  final List<RitaseItem> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool loading;
  final String? error;

  bool get hasMore => currentPage < lastPage;

  RitaseRiwayatState copyWith({
    List<RitaseItem>? items,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? loading,
    String? error,
  }) => RitaseRiwayatState(
    items: items ?? this.items,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    error: error,
  );
}

class RitaseRiwayatController extends Notifier<RitaseRiwayatState> {
  @override
  RitaseRiwayatState build() {
    Future.microtask(() => _loadPage(page: 1));
    return const RitaseRiwayatState(loading: true);
  }

  Future<void> _loadPage({required int page}) async {
    try {
      final result = await ref
          .read(armadaRepositoryProvider)
          .getRitase(page: page);
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
        error: 'Gagal memuat riwayat ritase.',
      );
    }
  }

  Future<void> refresh() => _loadPage(page: 1);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    await _loadPage(page: state.currentPage + 1);
  }
}

final ritaseRiwayatProvider =
    NotifierProvider<RitaseRiwayatController, RitaseRiwayatState>(
      RitaseRiwayatController.new,
    );

// ---------------------------------------------------------------------------
// Helpers armada (Section 21 — PIC absenkan helper)
// ---------------------------------------------------------------------------

final helpersProvider = FutureProvider.autoDispose<List<Helper>>((ref) {
  return ref.watch(armadaRepositoryProvider).getHelpers();
});
