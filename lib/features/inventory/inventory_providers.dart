import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/pending_action.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'inventory_models.dart';
import 'inventory_repository.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(api: ref.watch(apiClientProvider)),
);

final inventorySummaryProvider = FutureProvider.autoDispose<InventorySummary>(
  (ref) => ref.watch(inventoryRepositoryProvider).getSummary(),
);

final inventoryStokProvider = FutureProvider.autoDispose<List<InventoryItem>>(
  (ref) => ref.watch(inventoryRepositoryProvider).getStok(),
);

final inventoryRequestsProvider =
    FutureProvider.autoDispose<List<InventoryRequest>>(
      (ref) => ref.watch(inventoryRepositoryProvider).getRequests(),
    );

final inventoryRequestDetailProvider = FutureProvider.autoDispose
    .family<InventoryRequest, String>(
      (ref, id) => ref.watch(inventoryRepositoryProvider).getRequestDetail(id),
    );

// ---------------------------------------------------------------------------
// Riwayat mutasi stok (GET /inventory/mutasi) — filter + pagination
// ---------------------------------------------------------------------------

/// Filter layar Riwayat Inventory: tipe mutasi, kategori, rentang tanggal.
class InventoryMutasiFilter {
  const InventoryMutasiFilter({
    this.tipe,
    this.kategori,
    this.tanggalMulai,
    this.tanggalAkhir,
  });

  final MutasiTipe? tipe;
  final String? kategori;
  final DateTime? tanggalMulai;
  final DateTime? tanggalAkhir;

  @override
  bool operator ==(Object other) =>
      other is InventoryMutasiFilter &&
      other.tipe == tipe &&
      other.kategori == kategori &&
      other.tanggalMulai == tanggalMulai &&
      other.tanggalAkhir == tanggalAkhir;

  @override
  int get hashCode =>
      Object.hash(tipe, kategori, tanggalMulai, tanggalAkhir);
}

class InventoryMutasiFilterNotifier extends Notifier<InventoryMutasiFilter> {
  @override
  InventoryMutasiFilter build() => const InventoryMutasiFilter();

  void set(InventoryMutasiFilter filter) => state = filter;
}

final inventoryMutasiFilterProvider = NotifierProvider<
  InventoryMutasiFilterNotifier,
  InventoryMutasiFilter
>(InventoryMutasiFilterNotifier.new);

class InventoryMutasiState {
  const InventoryMutasiState({
    this.items = const [],
    this.currentPage = 0,
    this.lastPage = 1,
    this.total = 0,
    this.loading = false,
    this.error,
  });

  final List<StokMutasi> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool loading;
  final String? error;

  bool get hasMore => currentPage < lastPage;

  InventoryMutasiState copyWith({
    List<StokMutasi>? items,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? loading,
    String? error,
  }) => InventoryMutasiState(
    items: items ?? this.items,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    error: error,
  );
}

class InventoryMutasiController extends Notifier<InventoryMutasiState> {
  @override
  InventoryMutasiState build() {
    final filter = ref.watch(inventoryMutasiFilterProvider);
    Future.microtask(() => _loadPage(filter, page: 1));
    return const InventoryMutasiState(loading: true);
  }

  Future<void> _loadPage(
    InventoryMutasiFilter filter, {
    required int page,
  }) async {
    try {
      final result = await ref
          .read(inventoryRepositoryProvider)
          .getMutasi(
            kategori: filter.kategori,
            bahanBakuId: null,
            tanggalMulai: filter.tanggalMulai,
            tanggalAkhir: filter.tanggalAkhir,
            page: page,
          );
      if (ref.read(inventoryMutasiFilterProvider) != filter) return;
      final items = result.items.where((m) {
        if (filter.tipe != null && m.tipe != filter.tipe) return false;
        return true;
      }).toList();
      state = state.copyWith(
        items: page == 1 ? items : [...state.items, ...items],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        loading: false,
      );
    } on ApiException catch (e) {
      if (ref.read(inventoryMutasiFilterProvider) != filter) return;
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      if (ref.read(inventoryMutasiFilterProvider) != filter) return;
      state = state.copyWith(
        loading: false,
        error: 'Gagal memuat riwayat mutasi.',
      );
    }
  }

  Future<void> refresh() =>
      _loadPage(ref.read(inventoryMutasiFilterProvider), page: 1);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    await _loadPage(
      ref.read(inventoryMutasiFilterProvider),
      page: state.currentPage + 1,
    );
  }
}

final inventoryMutasiProvider = NotifierProvider<
  InventoryMutasiController,
  InventoryMutasiState
>(InventoryMutasiController.new);

/// Riwayat mutasi untuk 1 barang spesifik (layar Detail Stok) — muat 50
/// item pertama agar panel detail cukup informatif tanpa pagination token.
final inventoryMaterialMutasiProvider = FutureProvider.autoDispose
    .family<StokMutasiPage, String>(
      (ref, id) =>
          ref.watch(inventoryRepositoryProvider).getMaterialMutasi(id, perPage: 50),
    );

// ---------------------------------------------------------------------------
// Proses request sparepart dari workshop
// ---------------------------------------------------------------------------

class InventoryProsesResult {
  const InventoryProsesResult({this.error});

  final String? error;
}

class InventoryProsesState {
  const InventoryProsesState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

class InventoryProsesController extends Notifier<InventoryProsesState> {
  @override
  InventoryProsesState build() => const InventoryProsesState();

  Future<InventoryProsesResult> proses(String id, List<String> itemIds) async {
    if (state.busy) return const InventoryProsesResult();
    state = const InventoryProsesState(busy: true);
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .prosesRequest(id: id, itemIds: itemIds);
      ref.invalidate(inventoryRequestsProvider);
      ref.invalidate(inventoryRequestDetailProvider(id));
      ref.invalidate(inventorySummaryProvider);
      return const InventoryProsesResult();
    } on ApiException catch (e) {
      return InventoryProsesResult(error: e.message);
    } catch (_) {
      return const InventoryProsesResult(error: 'Gagal memproses request.');
    } finally {
      state = const InventoryProsesState();
    }
  }
}

final inventoryProsesProvider =
    NotifierProvider<InventoryProsesController, InventoryProsesState>(
      InventoryProsesController.new,
    );

// ---------------------------------------------------------------------------
// Stok Opname
// ---------------------------------------------------------------------------

final inventoryOpnameMaterialsProvider =
    FutureProvider.autoDispose<List<OpnameItem>>(
      (ref) => ref.watch(inventoryRepositoryProvider).getOpnameMaterials(),
    );

class InventoryOpnameResult {
  const InventoryOpnameResult({this.error});

  final String? error;
}

class InventoryOpnameState {
  const InventoryOpnameState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

class InventoryOpnameController extends Notifier<InventoryOpnameState> {
  static const _uuid = Uuid();

  @override
  InventoryOpnameState build() => const InventoryOpnameState();

  /// Simpan hasil hitung fisik via outbox (tahan offline).
  Future<InventoryOpnameResult> submit({
    required String titikId,
    required String tanggal,
    required List<OpnameSubmitItem> items,
  }) async {
    if (state.busy) return const InventoryOpnameResult();
    if (items.isEmpty) {
      return const InventoryOpnameResult(
        error: 'Belum ada item yang dihitung.',
      );
    }
    state = const InventoryOpnameState(busy: true);
    try {
      final action = PendingAction(
        id: _uuid.v4(),
        clientUuid: _uuid.v4(),
        endpoint: PendingEndpoint.inventoryOpname,
        payloadJson: const {},
        payloadData: {
          'titik_id': titikId,
          'tanggal': tanggal,
          'items': items.map((i) => i.toJson()).toList(),
        },
        createdAt: DateTime.now(),
        idempotencyKey: _uuid.v4(),
      );
      final sync = ref.read(outboxSyncServiceProvider);
      await ref.read(outboxRepositoryProvider).enqueue(action, sync.send);
      ref.invalidate(inventoryOpnameMaterialsProvider);
      ref.invalidate(inventoryStokProvider);
      ref.invalidate(inventorySummaryProvider);
      return const InventoryOpnameResult();
    } on ApiException catch (e) {
      return InventoryOpnameResult(error: e.message);
    } catch (_) {
      return const InventoryOpnameResult(error: 'Gagal menyimpan opname.');
    } finally {
      state = const InventoryOpnameState();
    }
  }
}

final inventoryOpnameProvider =
    NotifierProvider<InventoryOpnameController, InventoryOpnameState>(
      InventoryOpnameController.new,
    );
