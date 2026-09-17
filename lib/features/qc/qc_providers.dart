import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/pending_action.dart';
import '../presensi/presensi_providers.dart';
import '../produksi/produksi_providers.dart';
import '../auth/auth_providers.dart';
import 'models/qc_sample.dart';
import 'qc_repository.dart';
import 'qc_rules.dart';

final qcRepositoryProvider = Provider<QcRepository>(
  (ref) => QcRepository(api: ref.watch(apiClientProvider)),
);

// ---------------------------------------------------------------------------
// Riwayat QC (filter status + pagination)
// ---------------------------------------------------------------------------

const kQcStatuses = <String>['menunggu_hasil', 'lolos', 'tidak_lolos'];

class QcRiwayatFilter {
  const QcRiwayatFilter({this.status});

  final String? status;

  @override
  bool operator ==(Object other) =>
      other is QcRiwayatFilter && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

class QcRiwayatFilterNotifier extends Notifier<QcRiwayatFilter> {
  @override
  QcRiwayatFilter build() => const QcRiwayatFilter();

  void set(QcRiwayatFilter filter) => state = filter;
}

final qcRiwayatFilterProvider =
    NotifierProvider<QcRiwayatFilterNotifier, QcRiwayatFilter>(
      QcRiwayatFilterNotifier.new,
    );

class QcRiwayatState {
  const QcRiwayatState({
    this.items = const [],
    this.currentPage = 0,
    this.lastPage = 1,
    this.total = 0,
    this.loading = false,
    this.error,
  });

  final List<QcSample> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool loading;
  final String? error;

  bool get hasMore => currentPage < lastPage;

  QcRiwayatState copyWith({
    List<QcSample>? items,
    int? currentPage,
    int? lastPage,
    int? total,
    bool? loading,
    String? error,
  }) => QcRiwayatState(
    items: items ?? this.items,
    currentPage: currentPage ?? this.currentPage,
    lastPage: lastPage ?? this.lastPage,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    error: error,
  );
}

class QcRiwayatController extends Notifier<QcRiwayatState> {
  @override
  QcRiwayatState build() {
    final filter = ref.watch(qcRiwayatFilterProvider);
    Future.microtask(() => _loadPage(filter, page: 1));
    return const QcRiwayatState(loading: true);
  }

  Future<void> _loadPage(QcRiwayatFilter filter, {required int page}) async {
    try {
      final result = await ref
          .read(qcRepositoryProvider)
          .getRiwayat(status: filter.status, page: page);
      if (ref.read(qcRiwayatFilterProvider) != filter) return;
      state = state.copyWith(
        items: page == 1 ? result.items : [...state.items, ...result.items],
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        total: result.total,
        loading: false,
      );
    } on ApiException catch (e) {
      if (ref.read(qcRiwayatFilterProvider) != filter) return;
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      if (ref.read(qcRiwayatFilterProvider) != filter) return;
      state = state.copyWith(loading: false, error: 'Gagal memuat riwayat QC.');
    }
  }

  Future<void> refresh() =>
      _loadPage(ref.read(qcRiwayatFilterProvider), page: 1);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    await _loadPage(
      ref.read(qcRiwayatFilterProvider),
      page: state.currentPage + 1,
    );
  }
}

final qcRiwayatProvider = NotifierProvider<QcRiwayatController, QcRiwayatState>(
  QcRiwayatController.new,
);

/// Peta sessionId → sample yang masih menunggu hasil uji tekan.
/// Dipakai halaman sesi aktif untuk memutuskan tombol mana yang tampil:
/// "Catat Slump Test" vs "Catat Uji Tekan".
final waitingSamplesBySessionProvider =
    FutureProvider.autoDispose<Map<String, QcSample>>((ref) async {
      final page = await ref
          .watch(qcRepositoryProvider)
          .getRiwayat(status: 'menunggu_hasil', perPage: 50)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw ApiException(
              'Server tidak merespons saat memuat data QC.\nPeriksa koneksi internet Anda\nCoba lagi atau hubungi admin.',
            ),
          );
      final map = <String, QcSample>{};
      for (final s in page.items) {
        final sid = s.sessionId;
        if (sid != null && sid.isNotEmpty && !map.containsKey(sid)) {
          map[sid] = s;
        }
      }
      return map;
    });

// ---------------------------------------------------------------------------
// Home QC — queue-first
// ---------------------------------------------------------------------------

/// Ringkasan home QC (queue):
/// - [waitingQueue] = antrian sampel `menunggu_hasil` (dedupe per sesi,
///   karena tulis uji-tekan per `production_session_id`);
/// - [waitingTotal] = total `menunggu_hasil` (exact, dari pagination server);
/// - [selesaiHariIni] = sampel terminal yang waktu hasilnya BENAR-BENAR
///   jatuh hari ini (filter tanggal murni).
class QcHomeData {
  const QcHomeData({
    required this.waitingTotal,
    required this.waitingQueue,
    required this.selesaiHariIni,
  });

  final int waitingTotal;
  final List<QcSample> waitingQueue;
  final List<QcSample> selesaiHariIni;
}

final qcHomeProvider = FutureProvider.autoDispose<QcHomeData>((ref) async {
  final repo = ref.watch(qcRepositoryProvider);
  final results = await Future.wait<Object>([
    repo.getRiwayat(status: 'menunggu_hasil', perPage: 50),
    _allQcSamples(repo, 'lolos'),
    _allQcSamples(repo, 'tidak_lolos'),
  ]).timeout(
    const Duration(seconds: 20),
    onTimeout: () => throw ApiException(
      'Server tidak merespons saat memuat data QC.\nPeriksa koneksi internet Anda\nCoba lagi atau hubungi admin.',
    ),
  );

  final waiting = results[0] as QcRiwayatPage;
  final seen = <String>{};
  final queue = <QcSample>[];
  for (final s in waiting.items) {
    final sid = s.sessionId;
    if (sid == null || sid.isEmpty) {
      queue.add(s);
      continue;
    }
    if (seen.add(sid)) queue.add(s);
  }

  final terminal = <QcSample>[
    ...(results[1] as List<QcSample>),
    ...(results[2] as List<QcSample>),
  ];
  return QcHomeData(
    waitingTotal: waiting.total,
    waitingQueue: queue,
    selesaiHariIni: qcSelesaiHariIni(terminal, DateTime.now()),
  );
});

/// Ambil SEMUA halaman riwayat status terminal (max per_page 50 di backend).
/// Tanpa ini "Selesai Hari Ini" bisa terpotong >50 sampel per status.
Future<List<QcSample>> _allQcSamples(QcRepository repo, String status) async {
  final items = <QcSample>[];
  var page = 1;
  while (true) {
    final res = await repo.getRiwayat(status: status, perPage: 50, page: page);
    items.addAll(res.items);
    if (!res.hasMore) return items;
    page++;
  }
}

// ---------------------------------------------------------------------------
// Tulis: slump test / uji tekan via outbox (client_uuid idempotent)
// ---------------------------------------------------------------------------

class QcSubmitResult {
  const QcSubmitResult({
    this.delivered = false,
    this.queued = false,
    this.error,
  });

  final bool delivered;
  final bool queued;
  final String? error;
}

class QcSubmitState {
  const QcSubmitState({this.busy = false});

  final bool busy;
}

class QcSubmitController extends Notifier<QcSubmitState> {
  static const _uuid = Uuid();

  @override
  QcSubmitState build() => const QcSubmitState();

  void _invalidateQueries() {
    ref.invalidate(waitingSamplesBySessionProvider);
    ref.invalidate(qcHomeProvider);
  }

  /// POST /qc/slump-test — client_uuid dibuat SEKALI saat aksi dibuat.
  Future<QcSubmitResult> slumpTest({
    required String sessionId,
    required double nilaiSlump,
    String? catatan,
  }) async {
    if (state.busy) return const QcSubmitResult(error: 'Sedang memproses.');

    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.qcSlumpTest,
      payloadJson: const {},
      payloadData: {
        'production_session_id': sessionId,
        'nilai_slump': nilaiSlump,
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    state = const QcSubmitState(busy: true);
    try {
      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref
          .read(outboxRepositoryProvider)
          .enqueue(action, sync.send);
      if (result.delivered) {
        _invalidateQueries();
        return const QcSubmitResult(delivered: true);
      }
      if (result.permanentlyFailed) {
        return QcSubmitResult(
          error: result.errorMessage ?? 'Gagal mencatat slump test.',
        );
      }
      return const QcSubmitResult(queued: true);
    } on ApiException catch (e) {
      return QcSubmitResult(error: e.message);
    } catch (_) {
      return const QcSubmitResult(error: 'Gagal mencatat slump test.');
    } finally {
      state = const QcSubmitState();
    }
  }

  /// POST /qc/uji-tekan — sesi harus punya sample slump menunggu hasil.
  /// 422 "tidak ada sample menunggu" diteruskan sebagai [QcSubmitResult.error].
  Future<QcSubmitResult> ujiTekan({
    required String sessionId,
    required double hasilUjiTekan,
    double? targetMpa,
    String? catatan,
  }) async {
    if (state.busy) return const QcSubmitResult(error: 'Sedang memproses.');

    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.qcUjiTekan,
      payloadJson: const {},
      payloadData: {
        'production_session_id': sessionId,
        'hasil_uji_tekan': hasilUjiTekan,
        'target_mpa': ?targetMpa,
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    state = const QcSubmitState(busy: true);
    try {
      final sync = ref.read(outboxSyncServiceProvider);
      final result = await ref
          .read(outboxRepositoryProvider)
          .enqueue(action, sync.send);
      if (result.delivered) {
        _invalidateQueries();
        ref.invalidate(sesiAktifProvider);
        return const QcSubmitResult(delivered: true);
      }
      if (result.permanentlyFailed) {
        return QcSubmitResult(
          error: result.errorMessage ?? 'Gagal mencatat uji tekan.',
        );
      }
      return const QcSubmitResult(queued: true);
    } on ApiException catch (e) {
      // Termasuk 422 "tidak ada sample slump test yang menunggu hasil"
      // — UI mengarahkan user mencatat slump test dulu.
      return QcSubmitResult(error: e.message);
    } catch (_) {
      return const QcSubmitResult(error: 'Gagal mencatat uji tekan.');
    } finally {
      state = const QcSubmitState();
    }
  }
}

final qcSubmitProvider = NotifierProvider<QcSubmitController, QcSubmitState>(
  QcSubmitController.new,
);

// ---------------------------------------------------------------------------
// Detail QC
// ---------------------------------------------------------------------------

final qcDetailProvider = FutureProvider.autoDispose.family<QcSample, String>(
  (ref, id) => ref.watch(qcRepositoryProvider).getDetail(id),
);
