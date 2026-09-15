import '../../core/api_client.dart';
import '../../core/api_response.dart';
import '../armada/models/servis_armada.dart';
import 'workshop_models.dart';

/// Repository modul Workshop — Antrian Kerja (Section 14c).
/// Mengelola antrian servis, detail job, checklist, foto bukti, dan
/// request sparepart.
class WorkshopRepository {
  WorkshopRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// GET /servis-armada — Antrian workshop (servis yang disetujui/dikerjakan).
  /// Filter status: 'disetujui' (menunggu), 'dikerjakan', 'selesai'.
  Future<List<WorkshopJob>> getAntrianServis({String? status}) async {
    final res = await _api.get<List<WorkshopJob>>(
      '/servis-armada',
      query: {'status': ?status},
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        final items =
            map['data'] ?? map['items'] ?? (raw is List ? raw : const []);
        return <WorkshopJob>[
          if (items is List)
            for (final e in items)
              if (e is Map)
                // Hanya pekerjaan yang benar-benar masuk antrian:
                // disetujui (menunggu), dikerjakan, atau selesai.
                // 'diajukan' & 'ditolak' BUKAN pekerjaan workshop.
                if (isWorkForWorkshop(
                  ServisArmada.fromJson(Map<String, dynamic>.from(e)),
                ))
                  WorkshopJob.fromServisArmada(
                    ServisArmada.fromJson(Map<String, dynamic>.from(e)),
                  ),
        ];
      },
    );
    return res.data ?? const [];
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
  Future<WorkshopTodoItem> uploadTodoPhoto({
    required String jobId,
    required String todoId,
    required String photoPath,
  }) async {
    final res = await _api.postMultipart<WorkshopTodoItem>(
      '/workshop/job/$jobId/todo/$todoId/photo',
      fields: {},
      files: [MultipartFileSpec('photo', photoPath)],
      parse: (raw) =>
          WorkshopTodoItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    _ensureSuccess(res);
    return res.data!;
  }

  /// POST /workshop/job/{id}/request-sparepart — Request sparepart dari
  /// inventory untuk job ini.
  Future<void> requestSparepart({
    required String jobId,
    required List<SparepartRequestItem> items,
    String? catatan,
  }) async {
    final res = await _api.post<Object?>(
      '/workshop/job/$jobId/request-sparepart',
      body: {
        'items': items.map((i) => i.toJson()).toList(),
        'catatan': ?catatan,
      },
    );
    _ensureSuccess(res);
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
