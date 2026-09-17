import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/api_response.dart';
import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/outbox_sync_service.dart';
import '../../core/outbox/pending_action.dart';
import '../armada/models/servis_armada.dart';
import 'workshop_models.dart';

/// Repository modul Workshop — Antrian Kerja (Section 14c).
/// Mengelola antrian servis, detail job, checklist, foto bukti, dan
/// request sparepart.
class WorkshopRepository {
  WorkshopRepository({
    required ApiClient api,
    required OutboxRepository outbox,
    required OutboxSyncService sync,
  }) : _api = api,
       _outbox = outbox,
       _sync = sync;

  final ApiClient _api;
  final OutboxRepository _outbox;
  final OutboxSyncService _sync;
  static const _uuid = Uuid();

  /// GET /servis-armada — Antrian workshop (servis yang disetujui/dikerjakan).
  /// Filter status: 'disetujui' (menunggu), 'dikerjakan', 'selesai'.
  Future<List<WorkshopJob>> getAntrianServis({String? status}) async {
    final res = await _api.get<List<WorkshopJob>>(
      '/servis-armada',
      query: {'status': ?status},
      parse: antrianFromRaw,
    );
    return res.data ?? const [];
  }

  /// Parse response `/servis-armada` menjadi daftar pekerjaan workshop.
  ///
  /// HANYA pekerjaan yang benar-benar masuk antrian: `disetujui` (menunggu),
  /// `dikerjakan`, atau `selesai`. `diajukan` & `ditolak` BUKAN pekerjaan
  /// workshop — ditolak TIDAK boleh tampil sebagai pending.
  static List<WorkshopJob> antrianFromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final items =
        map['data'] ?? map['items'] ?? (raw is List ? raw : const []);
    return <WorkshopJob>[
      if (items is List)
        for (final e in items)
          if (e is Map)
            if (isWorkForWorkshop(
              ServisArmada.fromJson(Map<String, dynamic>.from(e)),
            ))
              WorkshopJob.fromServisArmada(
                ServisArmada.fromJson(Map<String, dynamic>.from(e)),
              ),
    ];
  }

  /// GET /servis-armada/{id} — Detail job servis beserta todo items.
  Future<WorkshopJobDetail> getDetailJob(String id) async {
    final res = await _api.get<WorkshopJobDetail>(
      '/servis-armada/$id',
      parse: (raw) =>
          WorkshopJobDetail.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    _ensureSuccess(res);
    return res.data!;
  }

  /// POST /servis-armada/{id}/mulai — Mulai mengerjakan servis.
  Future<void> mulaiPengerjaan(String id) async {
    final res = await _api.post<Object?>('/servis-armada/$id/mulai');
    _ensureSuccess(res);
  }

  /// POST /workshop/job/{id}/todo/{todoId}/toggle — Toggle status todo item.
  Future<WorkshopTodoItem> toggleTodoItem({
    required String jobId,
    required String todoId,
    required bool isDone,
  }) async {
    final res = await _api.post<WorkshopTodoItem>(
      '/workshop/job/$jobId/todo/$todoId/toggle',
      body: {'is_done': isDone},
      parse: (raw) =>
          WorkshopTodoItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    _ensureSuccess(res);
    return res.data!;
  }

  /// POST /workshop/job/{id}/todo/{todoId}/photo — Upload foto bukti todo.
  /// Lewat outbox (attachment satu file `photo`): offline → foto tetap
  /// tersimpan di perangkat dan dikirim otomatis. Retry memakai
  /// Idempotency-Key yang SAMA persis.
  Future<OutboxSendResult> uploadTodoPhoto({
    required String jobId,
    required String todoId,
    required String photoPath,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.workshopTodoPhoto,
      payloadJson: {'job_id': jobId, 'todo_id': todoId},
      photoLocalPath: photoPath,
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    return _outbox.enqueue(action, _sync.send);
  }

  /// POST /workshop/job/{id}/request-sparepart — Request sparepart dari
  /// inventory untuk job ini. Lewat outbox + route ber-middleware
  /// idempotency: retry tidak menggandakan order sparepart.
  Future<OutboxSendResult> requestSparepart({
    required String jobId,
    required List<SparepartRequestItem> items,
    String? catatan,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.workshopRequestSparepart,
      payloadJson: const {},
      payloadData: {
        'job_id': jobId,
        'items': items.map((i) => i.toJson()).toList(),
        'catatan': ?catatan,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    return _outbox.enqueue(action, _sync.send);
  }

  /// POST /servis-armada/{id}/selesai — Tandai servis selesai.
  Future<void> tandaiSelesai({
    required String id,
    String? catatanWorkshop,
  }) async {
    final res = await _api.post<Object?>(
      '/servis-armada/$id/selesai',
      body: {'catatan_workshop': ?catatanWorkshop},
    );
    _ensureSuccess(res);
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }

  /// True jika servis adalah pekerjaan yang valid untuk antrian workshop.
  static bool isWorkForWorkshop(ServisArmada servis) =>
      servis.isDisetujui || servis.isDikerjakan || servis.isSelesai;
}
