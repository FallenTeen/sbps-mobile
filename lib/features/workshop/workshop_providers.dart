import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/pending_action.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'workshop_models.dart';
import 'workshop_repository.dart';

final workshopRepositoryProvider = Provider<WorkshopRepository>(
  (ref) => WorkshopRepository(api: ref.watch(apiClientProvider)),
);

// ---------------------------------------------------------------------------
// Antrian Workshop
// ---------------------------------------------------------------------------

class WorkshopQueueState {
  const WorkshopQueueState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.filter = 'menunggu',
    this.refreshing = false,
  });

  final List<WorkshopJob> items;
  final bool loading;
  final String? error;
  final String filter;
  final bool refreshing;

  int get menungguCount =>
      items.where((j) => j.status == WorkshopJobStatus.menunggu).length;

  int get dikerjakanCount =>
      items.where((j) => j.status == WorkshopJobStatus.dikerjakan).length;

  WorkshopQueueState copyWith({
    List<WorkshopJob>? items,
    bool? loading,
    String? error,
    String? filter,
    bool? refreshing,
  }) {
    return WorkshopQueueState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      error: error,
      filter: filter ?? this.filter,
      refreshing: refreshing ?? this.refreshing,
    );
  }

  List<WorkshopJob> get filteredItems {
    return switch (filter) {
      'menunggu' =>
        items.where((j) => j.status == WorkshopJobStatus.menunggu).toList(),
      'dikerjakan' =>
        items.where((j) => j.status == WorkshopJobStatus.dikerjakan).toList(),
      _ => items.where((j) => j.status == WorkshopJobStatus.selesai).toList(),
    };
  }
}

class WorkshopQueueController extends Notifier<WorkshopQueueState> {
  @override
  WorkshopQueueState build() {
    Future.microtask(_load);
    return const WorkshopQueueState(loading: true);
  }

  Future<void> _load() async {
    // Ambil sekaligus menunggu + dikerjakan + selesai tanpa filter.
    try {
      final jobs = await ref
          .read(workshopRepositoryProvider)
          .getAntrianServis();
      state = state.copyWith(items: jobs, loading: false);
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

  void setFilter(String filter) => state = state.copyWith(filter: filter);
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

/// Hasil alur submit di detail job.
class WorkshopSubmitResult {
  const WorkshopSubmitResult({this.error});

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

  void _invalidateQueries() {
    ref.invalidate(workshopQueueProvider);
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
      await ref.read(outboxRepositoryProvider).enqueue(action, sync.send);
      _invalidateQueries();
      return const WorkshopSubmitResult();
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
      await ref.read(outboxRepositoryProvider).enqueue(action, sync.send);
      _invalidateQueries();
      return const WorkshopSubmitResult();
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
