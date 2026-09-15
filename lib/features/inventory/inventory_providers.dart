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
