import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/pending_action.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'models/master.dart';
import 'models/production_session.dart';
import 'produksi_repository.dart';

final produksiRepositoryProvider = Provider<ProduksiRepository>(
  (ref) => ProduksiRepository(api: ref.watch(apiClientProvider)),
);

// ---------------------------------------------------------------------------
// Master data (§8.6)
// ---------------------------------------------------------------------------

final mesinProvider = FutureProvider.autoDispose<List<MesinMaster>>(
  (ref) => ref.watch(produksiRepositoryProvider).getMesin(),
);

final produkProvider = FutureProvider.autoDispose<List<ProdukMaster>>(
  (ref) => ref.watch(produksiRepositoryProvider).getProduk(),
);

final bahanBakuProvider = FutureProvider.autoDispose<List<BahanBakuMaster>>(
  (ref) => ref.watch(produksiRepositoryProvider).getBahanBaku(),
);

// ---------------------------------------------------------------------------
// Query: sesi aktif / riwayat / progress
// ---------------------------------------------------------------------------

final sesiAktifProvider = FutureProvider.autoDispose<List<ProductionSession>>(
  (ref) => ref
      .watch(produksiRepositoryProvider)
      .getSesiAktif()
      .timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw ApiException(
          'Server tidak merespons saat memuat sesi.\nPeriksa koneksi internet Anda\nCoba lagi atau hubungi admin.',
        ),
      ),
);

class TitikProgressData {
  const TitikProgressData({required this.tanggal, required this.items});

  final String tanggal;
  final List<TitikProgressItem> items;
}

final titikProgressProvider = FutureProvider.autoDispose<TitikProgressData>((
  ref,
) async {
  final (tanggal, items) = await ref
      .watch(produksiRepositoryProvider)
      .getTitikProgress();
  return TitikProgressData(tanggal: tanggal, items: items);
});

/// Filter riwayat: tanggal (YYYY-MM-DD) + mesin opsional.
class RiwayatFilter {
  const RiwayatFilter({this.tanggal, this.mesinId});

  final String? tanggal;
  final String? mesinId;

  @override
  bool operator ==(Object other) =>
      other is RiwayatFilter &&
      other.tanggal == tanggal &&
      other.mesinId == mesinId;

  @override
  int get hashCode => Object.hash(tanggal, mesinId);
}

class RiwayatFilterNotifier extends Notifier<RiwayatFilter> {
  @override
  RiwayatFilter build() => const RiwayatFilter();

  void set(RiwayatFilter filter) => state = filter;
}

final riwayatFilterProvider =
    NotifierProvider<RiwayatFilterNotifier, RiwayatFilter>(
      RiwayatFilterNotifier.new,
    );

/// State riwayat ber-paginasi; [loadMore] menambah halaman berikutnya.
class RiwayatProduksiState {
  const RiwayatProduksiState({
    this.items = const [],
    this.currentPage = 0,
    this.lastPage = 1,
    this.total = 0,
    this.loading = false,
    this.error,
  });

  final List<ProductionSession> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool loading;
  final String? error;

  bool get hasMore => currentPage < lastPage;

  RiwayatProduksiState copyWith({
    List<ProductionSession>? items,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? loading,
    String? error,
  }) {
    return RiwayatProduksiState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      lastPage: lastPage ?? this.lastPage,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

/// Controller riwayat. Build mem-watch [riwayatFilterProvider] sehingga
/// ganti filter otomatis memuat ulang halaman pertama.
class RiwayatProduksiController extends Notifier<RiwayatProduksiState> {
  @override
  RiwayatProduksiState build() {
    final filter = ref.watch(riwayatFilterProvider);
    Future.microtask(() => _loadPage(filter, page: 1));
    return const RiwayatProduksiState(loading: true);
  }

  Future<void> _loadPage(RiwayatFilter filter, {required int page}) async {
    try {
      final result = await ref
          .read(produksiRepositoryProvider)
          .getRiwayat(
            tanggal: filter.tanggal,
            mesinId: filter.mesinId,
            page: page,
          );
      // Abaikan hasil bila filter sudah berganti lagi saat fetch berjalan.
      if (ref.read(riwayatFilterProvider) != filter) return;
      state = state.copyWith(
        items: page == 1 ? result.items : [...state.items, ...result.items],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        loading: false,
      );
    } on ApiException catch (e) {
      if (ref.read(riwayatFilterProvider) != filter) return;
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      if (ref.read(riwayatFilterProvider) != filter) return;
      state = state.copyWith(loading: false, error: 'Gagal memuat riwayat.');
    }
  }

  Future<void> refresh() => _loadPage(ref.read(riwayatFilterProvider), page: 1);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    await _loadPage(
      ref.read(riwayatFilterProvider),
      page: state.currentPage + 1,
    );
  }
}

final riwayatProduksiProvider =
    NotifierProvider<RiwayatProduksiController, RiwayatProduksiState>(
      RiwayatProduksiController.new,
    );

// ---------------------------------------------------------------------------
// Tulis: mulai / selesai via outbox (client_uuid idempotent di body)
// ---------------------------------------------------------------------------

/// Hasil alur submit ke UI.
class ProduksiSubmitResult {
  const ProduksiSubmitResult({
    this.delivered = false,
    this.queued = false,
    this.error,
  });

  /// true = server menerima aksi.
  final bool delivered;

  /// true = offline/gagal jaringan, tersimpan di outbox.
  final bool queued;
  final String? error;
}

class ProduksiSubmitState {
  const ProduksiSubmitState({this.busy = false});

  final bool busy;
}

class ProduksiSubmitController extends Notifier<ProduksiSubmitState> {
  static const _uuid = Uuid();

  @override
  ProduksiSubmitState build() => const ProduksiSubmitState();

  void _invalidateQueries() {
    ref.invalidate(sesiAktifProvider);
    ref.invalidate(titikProgressProvider);
  }

  /// POST /produksi/mulai — client_uuid dibuat SEKALI saat aksi dibuat
  /// dan ikut tersimpan di outbox sehingga retry tidak membuat sesi dobel.
  Future<ProduksiSubmitResult> mulai({
    required String mesinId,
    required String produkId,
    String? titikId,
    String? catatan,
  }) async {
    if (state.busy)
      return const ProduksiSubmitResult(error: 'Sedang memproses.');

    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.produksiMulai,
      payloadJson: const {},
      payloadData: {
        'mesin_id': mesinId,
        'produk_id': produkId,
        if (titikId != null && titikId.isNotEmpty) 'titik_id': titikId,
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    state = const ProduksiSubmitState(busy: true);
    try {
      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref
          .read(outboxRepositoryProvider)
          .enqueue(action, sync.send);
      if (result.delivered) {
        _invalidateQueries();
        return const ProduksiSubmitResult(delivered: true);
      }
      if (result.permanentlyFailed) {
        return ProduksiSubmitResult(
          error: result.errorMessage ?? 'Gagal memulai sesi. Coba lagi.',
        );
      }
      return const ProduksiSubmitResult(queued: true);
    } on ApiException catch (e) {
      return ProduksiSubmitResult(error: e.message);
    } catch (_) {
      return const ProduksiSubmitResult(error: 'Gagal memulai sesi.');
    } finally {
      state = const ProduksiSubmitState();
    }
  }

  /// POST /produksi/selesai/{sessionId} - [items] opsional untuk override
  /// konsumsi bahan baku manual (kosong = hitung otomatis dari BOM).
  Future<ProduksiSubmitResult> selesai({
    required String sessionId,
    required double hasilOutput,
    String? catatan,
    List<({String bahanBakuId, double jumlahTerpakai})> items = const [],
  }) async {
    if (state.busy)
      return const ProduksiSubmitResult(error: 'Sedang memproses.');

    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.produksiSelesai,
      payloadJson: const {},
      payloadData: {
        'session_id': sessionId,
        'hasil_output': hasilOutput,
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
        if (items.isNotEmpty)
          'items': [
            for (final item in items)
              {
                'bahan_baku_id': item.bahanBakuId,
                'jumlah_terpakai': item.jumlahTerpakai,
              },
          ],
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    state = const ProduksiSubmitState(busy: true);
    try {
      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref
          .read(outboxRepositoryProvider)
          .enqueue(action, sync.send);
      if (result.delivered) {
        _invalidateQueries();
        return const ProduksiSubmitResult(delivered: true);
      }
      if (result.permanentlyFailed) {
        return ProduksiSubmitResult(
          error: result.errorMessage ?? 'Gagal menutup sesi. Coba lagi.',
        );
      }
      return const ProduksiSubmitResult(queued: true);
    } on ApiException catch (e) {
      return ProduksiSubmitResult(error: e.message);
    } catch (_) {
      return const ProduksiSubmitResult(error: 'Gagal menutup sesi.');
    } finally {
      state = const ProduksiSubmitState();
    }
  }
}

final produksiSubmitProvider =
    NotifierProvider<ProduksiSubmitController, ProduksiSubmitState>(
      ProduksiSubmitController.new,
    );
