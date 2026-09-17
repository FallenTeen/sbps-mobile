import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/pending_action.dart';
import '../auth/auth_providers.dart';
import '../inventory/inventory_providers.dart';
import '../presensi/presensi_providers.dart';
import 'workshop_models.dart';
import 'workshop_repository.dart';
import 'workshop_rules.dart';

final workshopRepositoryProvider = Provider<WorkshopRepository>(
  (ref) => WorkshopRepository(
    api: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    sync: ref.watch(outboxSyncServiceProvider),
  ),
);

// ---------------------------------------------------------------------------
// Antrian Workshop
// ---------------------------------------------------------------------------

class WorkshopQueueState {
  const WorkshopQueueState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.refreshing = false,
    this.waitingSparepartJobIds = const {},
    this.sparepartError,
  });

  final List<WorkshopJob> items;
  final bool loading;
  final String? error;
  final bool refreshing;

  /// Id job yang sedang menunggu sparepart — dari request inventori yang
  /// masih `pending`/`diproses` (data nyata, bukan asumsi).
  final Set<String> waitingSparepartJobIds;

  /// Pesan bila status sparepart tidak bisa dimuat (jangan tampilkan angka
  /// yang menyesatkan ketika data tidak diketahui).
  final String? sparepartError;

  int get menungguCount =>
      items.where((j) => j.status == WorkshopJobStatus.menunggu).length;

  int get dikerjakanCount =>
      items.where((j) => j.status == WorkshopJobStatus.dikerjakan).length;

  /// Jumlah pekerjaan aktif (belum selesai) — "N pekerjaan" di ringkasan.
  int get activeCount =>
      items.where((j) => j.status != WorkshopJobStatus.selesai).length;

  /// Pekerjaan yang selesai HARI INI (berdasarkan tanggal, bukan asumsi).
  List<WorkshopJob> get selesaiHariIniJobs =>
      selesaiHariIni(items, DateTime.now());

  int get selesaiHariIniCount => selesaiHariIniJobs.length;

  int get menungguSparepartCount =>
      countMenungguSparepart(items, waitingSparepartJobIds);

  WorkshopQueueState copyWith({
    List<WorkshopJob>? items,
    bool? loading,
    String? error,
    bool? refreshing,
    Set<String>? waitingSparepartJobIds,
    String? sparepartError,
  }) {
    return WorkshopQueueState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
      refreshing: refreshing ?? this.refreshing,
      waitingSparepartJobIds: waitingSparepartJobIds ?? this.waitingSparepartJobIds,
      sparepartError: sparepartError ?? this.sparepartError,
    );
  }
}

class WorkshopQueueController extends Notifier<WorkshopQueueState> {
  @override
  WorkshopQueueState build() {
    Future.microtask(_load);
    return const WorkshopQueueState(loading: true);
  }

  Future<void> _load() async {
    // Ambil sekaligus menunggu + dikerjakan + selesai tanpa filter status,
    // lalu status sparepart dari request inventori yang belum beres.
    try {
      final jobs = await ref
          .read(workshopRepositoryProvider)
          .getAntrianServis();
      late Set<String> waiting;
      String? sparepartError;
      try {
        final results = await Future.wait([
          ref.read(inventoryRepositoryProvider).getRequests(status: 'pending'),
          ref.read(inventoryRepositoryProvider).getRequests(status: 'diproses'),
        ]);
        waiting = sparepartWaitingJobIds(
          jobs,
          results.expand((r) => r).toList(),
        );
      } on ApiException catch (e) {
        sparepartError = e.message;
        waiting = const {};
      } catch (_) {
        sparepartError = 'Status sparepart tidak bisa dimuat.';
        waiting = const {};
      }
      state = state.copyWith(
        items: jobs,
        loading: false,
        waitingSparepartJobIds: waiting,
        sparepartError: sparepartError,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Gagal memuat antrian.');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(refreshing: true);
    await _load();
    state = state.copyWith(refreshing: false);
  }
}

final workshopQueueProvider =
    NotifierProvider<WorkshopQueueController, WorkshopQueueState>(
      WorkshopQueueController.new,
    );

// ---------------------------------------------------------------------------
// Detail Job
// ---------------------------------------------------------------------------

final workshopJobDetailProvider = FutureProvider.autoDispose
    .family<WorkshopJobDetail, String>((ref, id) {
      return ref.watch(workshopRepositoryProvider).getDetailJob(id);
    });

/// Anti-duplikat foto bukti: true selama masih ada aksi outbox
/// `workshopTodoPhoto` menunggu untuk kombinasi `(jobId, todoId)`
/// (key = `"$jobId|$todoId"`). Blokir pengambilan ulang foto sampai
/// aksi lama terkirim/dihapus.
final pendingWorkshopTodoPhotoProvider = Provider.autoDispose
    .family<bool, String>((ref, key) {
      final actions = ref.watch(pendingActionsProvider).value ?? const [];
      return actions.any(
        (a) =>
            a.endpoint == PendingEndpoint.workshopTodoPhoto &&
            '${a.payloadJson['job_id']}|${a.payloadJson['todo_id']}' == key,
      );
    });

/// Hasil alur submit di detail job.
class WorkshopSubmitResult {
  const WorkshopSubmitResult({
    this.delivered = false,
    this.queued = false,
    this.error,
  });

  /// true = server sudah menerima (sync langsung sukses).
  final bool delivered;

  /// true = tersimpan di perangkat, dikirim saat online.
  final bool queued;

  final String? error;
}

class WorkshopSubmitState {
  const WorkshopSubmitState({this.busy = false, this.error});

  final bool busy;
  final String? error;
}

class WorkshopSubmitController extends Notifier<WorkshopSubmitState> {
  static const _uuid = Uuid();

  @override
  WorkshopSubmitState build() => const WorkshopSubmitState();

  void _invalidateQueries(String jobId) {
    ref.invalidate(workshopQueueProvider);
    ref.invalidate(workshopJobDetailProvider(jobId));
  }

  /// Mulai mengerjakan job (status menunggu -> dikerjakan).
  Future<WorkshopSubmitResult> mulaiPengerjaan(String jobId) async {
    if (state.busy) return const WorkshopSubmitResult();
    state = const WorkshopSubmitState(busy: true);
    try {
      final action = PendingAction(
        id: _uuid.v4(),
        clientUuid: _uuid.v4(),
        endpoint: PendingEndpoint.workshopMulai,
        payloadJson: const {},
        payloadData: {'job_id': jobId},
        createdAt: DateTime.now(),
        idempotencyKey: _uuid.v4(),
      );
      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref.read(outboxRepositoryProvider).enqueue(
        action,
        sync.send,
      );
      if (result.delivered) {
        _invalidateQueries(jobId);
        return const WorkshopSubmitResult(delivered: true);
      }
      if (result.permanentlyFailed) {
        return WorkshopSubmitResult(
          error: result.errorMessage ?? 'Gagal memulai pengerjaan.',
        );
      }
      return const WorkshopSubmitResult(queued: true);
    } on ApiException catch (e) {
      return WorkshopSubmitResult(error: e.message);
    } catch (_) {
      return const WorkshopSubmitResult(error: 'Gagal memulai pengerjaan.');
    } finally {
      state = const WorkshopSubmitState();
    }
  }

  /// Tandai job selesai (perlu semua todo beres).
  Future<WorkshopSubmitResult> tandaiSelesai({
    required String jobId,
    String? catatan,
  }) async {
    if (state.busy) return const WorkshopSubmitResult();
    state = const WorkshopSubmitState(busy: true);
    try {
      final action = PendingAction(
        id: _uuid.v4(),
        clientUuid: _uuid.v4(),
        endpoint: PendingEndpoint.workshopSelesai,
        payloadJson: const {},
        payloadData: {
          'job_id': jobId,
          if (catatan != null && catatan.trim().isNotEmpty)
            'catatan_workshop': catatan.trim(),
        },
        createdAt: DateTime.now(),
        idempotencyKey: _uuid.v4(),
      );
      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref.read(outboxRepositoryProvider).enqueue(
        action,
        sync.send,
      );
      if (result.delivered) {
        _invalidateQueries(jobId);
        return const WorkshopSubmitResult(delivered: true);
      }
      if (result.permanentlyFailed) {
        return WorkshopSubmitResult(
          error: result.errorMessage ?? 'Gagal menandai selesai.',
        );
      }
      return const WorkshopSubmitResult(queued: true);
    } on ApiException catch (e) {
      return WorkshopSubmitResult(error: e.message);
    } catch (_) {
      return const WorkshopSubmitResult(error: 'Gagal menandai selesai.');
    } finally {
      state = const WorkshopSubmitState();
    }
  }
}

final workshopSubmitProvider =
    NotifierProvider<WorkshopSubmitController, WorkshopSubmitState>(
      WorkshopSubmitController.new,
    );
