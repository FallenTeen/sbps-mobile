import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/api_response.dart';
import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/outbox_sync_service.dart';
import '../../core/outbox/pending_action.dart';
import 'models/servis_armada.dart';

/// Repository modul Servis Armada (Section 21).
/// Mengelola pengajuan servis, riwayat, detail, persetujuan/penolakan, dan master armada.
class ServisRepository {
  ServisRepository({
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

  /// GET /master/armada — daftar semua armada untuk dropdown ajuan servis.
  Future<List<MasterArmada>> getMasterArmada() async {
    final res = await _api.get<List<MasterArmada>>(
      '/master/armada',
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        final items = map['items'] ?? (raw is List ? raw : const []);
        return <MasterArmada>[
          if (items is List)
            for (final e in items)
              if (e is Map) MasterArmada.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  /// POST /servis-armada — Ajukan permohonan servis armada (Bagian 1).
  /// Lewat outbox: offline → antrean, retry memakai Idempotency-Key yang
  /// SAMA (route punya middleware idempotency) sehingga double-submit
  /// dibalas respons asli, bukan membuat ajuan kedua.
  Future<OutboxSendResult> submitAjuanServis({
    required String armadaId,
    required String keluhan,
    String? kategori,
    double? odometerSaatAjuan,
    double? jamOperasionalSaatAjuan,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.servisAjuan,
      payloadJson: const {},
      payloadData: {
        'armada_id': armadaId,
        'keluhan': keluhan,
        'kategori': ?kategori,
        'odometer_saat_ajuan': ?odometerSaatAjuan,
        'jam_operasional_saat_ajuan': ?jamOperasionalSaatAjuan,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(result.errorMessage ?? 'Gagal mengajukan servis.');
    }
    return result;
  }

  /// GET /servis-armada — Riwayat ajuan servis (paginasi).
  Future<ServisArmadaPage> getRiwayatServis({
    int page = 1,
    String? status,
  }) async {
    final res = await _api.get<ServisArmadaPage>(
      '/servis-armada',
      query: {'page': page, 'status': ?status},
      parse: ServisArmadaPage.fromRaw,
    );
    return res.data ??
        const ServisArmadaPage(
          items: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  /// GET /servis-armada/saya — Riwayat ajuan servis milik user aktif / armada yang di-PIC-kan.
  Future<List<ServisArmada>> getServisSaya() async {
    final res = await _api.get<List<ServisArmada>>(
      '/servis-armada/saya',
      parse: (raw) {
        final items = raw is List ? raw : (raw is Map ? (raw['items'] ?? raw['data']) : null);
        return [
          if (items is List)
            for (final e in items)
              if (e is Map)
                ServisArmada.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  /// GET /servis-armada/{id} — Detail ajuan servis beserta sparepart dan workshop log.
  Future<ServisArmada> getDetailServis(String id) async {
    final res = await _api.get<ServisArmada>(
      '/servis-armada/$id',
      parse: (raw) =>
          ServisArmada.fromJson(Map<String, dynamic>.from(raw as Map)),
    );
    _ensureSuccess(res);
    return res.data!;
  }

  /// POST /servis-armada/{id}/approve — Persetujuan servis oleh Kepala Divisi / Admin.
  Future<void> approveServis({required String id, String? catatan}) async {
    final res = await _api.post<Object?>(
      '/servis-armada/$id/approve',
      body: {'catatan': ?catatan},
    );
    _ensureSuccess(res);
  }

  /// POST /servis-armada/{id}/tolak — Penolakan servis dengan alasan.
  Future<void> tolakServis({required String id, required String alasan}) async {
    final res = await _api.post<Object?>(
      '/servis-armada/$id/tolak',
      body: {'alasan': alasan},
    );
    _ensureSuccess(res);
  }

  /// POST /servis-armada/eksternal — Pengajuan servis eksternal (TD-B1, TD-B2, TD-B5).
  Future<OutboxSendResult> submitServisEksternal({
    required String armadaId,
    required String namaBengkel,
    required String alamatBengkel,
    required String fotoBengkelPath,
    double? latitude,
    double? longitude,
    String? rincianPekerjaan,
    required double totalBiayaEstimasi,
    List<String> fotoNotaPaths = const [],
    double? odometer,
    double? jamOperasional,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.servisEksternalCreate,
      payloadJson: {
        'armada_id': armadaId,
        'nama_bengkel': namaBengkel,
        'alamat_bengkel': alamatBengkel,
        'tipe_servis': 'eksternal',
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (rincianPekerjaan != null && rincianPekerjaan.trim().isNotEmpty)
          'rincian_pekerjaan': rincianPekerjaan.trim(),
        'total_biaya_estimasi': totalBiayaEstimasi.toString(),
        if (odometer != null) 'odometer_saat_ajuan': odometer.toString(),
        if (jamOperasional != null)
          'jam_operasional_saat_ajuan': jamOperasional.toString(),
      },
      photoLocalPath: fotoBengkelPath,
      photoLocalPaths: fotoNotaPaths,
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(
        result.errorMessage ?? 'Gagal mengajukan servis eksternal.',
      );
    }
    return result;
  }

  /// POST /servis-armada/{id}/eksternal/nota — Tambah foto nota servis eksternal (TD-B4, TD-B5).
  Future<OutboxSendResult> submitServisEksternalNota({
    required String servisId,
    required List<String> fotoNotaPaths,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.servisEksternalNota,
      payloadJson: {'servis_id': servisId},
      photoLocalPaths: fotoNotaPaths,
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(
        result.errorMessage ?? 'Gagal mengunggah nota servis eksternal.',
      );
    }
    return result;
  }

  /// POST /servis-armada/{id}/foto-hasil — Tambah foto hasil pengerjaan (TD-B4, TD-B5).
  Future<OutboxSendResult> submitServisFotoHasil({
    required String servisId,
    required String fotoPath,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.servisEksternalFotoHasil,
      payloadJson: {'servis_id': servisId},
      photoLocalPath: fotoPath,
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(
        result.errorMessage ?? 'Gagal mengunggah foto hasil servis.',
      );
    }
    return result;
  }

  /// POST /servis-armada/{id}/selesai — Driver atau workshop menandai servis selesai (TD-B3).
  Future<void> selesaiServis({required String servisId}) async {
    final res = await _api.post<Object?>('/servis-armada/$servisId/selesai');
    _ensureSuccess(res);
  }

  /// POST /workshop/servis-eksternal/{id}/verifikasi — Verifikasi Workshop (TD-B7).
  Future<void> verifikasiServisEksternal({
    required String servisId,
    required String status,
    String? catatan,
  }) async {
    final res = await _api.post<Object?>(
      '/workshop/servis-eksternal/$servisId/verifikasi',
      body: {
        'status': status,
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
      },
    );
    _ensureSuccess(res);
  }

  /// GET /servis-armada?tipe_servis=eksternal — Daftar servis eksternal untuk verifikasi workshop (TD-B7).
  Future<List<ServisArmada>> getServisEksternalList() async {
    final res = await _api.get<List<ServisArmada>>(
      '/servis-armada',
      query: {'tipe_servis': 'eksternal'},
      parse: (raw) {
        final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
        final items = map['items'] ?? map['data'] ?? (raw is List ? raw : const []);
        return <ServisArmada>[
          if (items is List)
            for (final e in items)
              if (e is Map) ServisArmada.fromJson(Map<String, dynamic>.from(e)),
        ];
      },
    );
    return res.data ?? const [];
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}
