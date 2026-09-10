import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/outbox_sync_service.dart';
import '../../core/outbox/pending_action.dart';
import 'models/armada.dart';
import 'models/helper.dart';

/// Repository modul Armada (driver) — docs/api-mobile.md §Armada
/// dan manual-book Section 21.
///
/// Endpoint POST (tulis) di-route lewat outbox supaya bisa offline.
class ArmadaRepository {
  ArmadaRepository({
    required ApiClient api,
    required OutboxRepository outbox,
    required OutboxSyncService sync,
  })  : _api = api,
        _outbox = outbox,
        _sync = sync;

  final ApiClient _api;
  final OutboxRepository _outbox;
  final OutboxSyncService _sync;
  static const _uuid = Uuid();

  // ---------------------------------------------------------------------------
  // GET endpoints (read — tidak perlu outbox)
  // ---------------------------------------------------------------------------

  /// GET /armada/saya — kendaraan yang dipegang driver.
  Future<List<ArmadaSaya>> getArmadaSaya() async {
    final res = await _api.get<List<ArmadaSaya>>(
      '/armada/saya',
      parse: _parseList<ArmadaSaya>(ArmadaSaya.fromJson),
    );
    return res.data ?? const [];
  }

  /// GET /armada/ritase?page=&per_page= — riwayat pengiriman driver.
  Future<RitasePage> getRitase({int page = 1, int perPage = 15}) async {
    final res = await _api.get<RitasePage>(
      '/armada/ritase',
      query: {'page': page, 'per_page': perPage},
      parse: RitasePage.fromRaw,
    );
    return res.data ??
        const RitasePage(items: [], currentPage: 1, lastPage: 1, total: 0);
  }

  /// GET /armada/checklist-hari-ini — status checklist tiap armada hari ini.
  Future<List<ArmadaChecklist>> getChecklistHariIni() async {
    final res = await _api.get<List<ArmadaChecklist>>(
      '/armada/checklist-hari-ini',
      parse: _parseList<ArmadaChecklist>(ArmadaChecklist.fromJson),
    );
    return res.data ?? const [];
  }

  /// GET /armada/helper — daftar helper untuk PIC aktif.
  Future<List<Helper>> getHelpers() async {
    final res = await _api.get<List<Helper>>(
      '/armada/helper',
      parse: _parseList<Helper>(Helper.fromJson),
    );
    return res.data ?? const [];
  }

  // ---------------------------------------------------------------------------
  // POST endpoints (write — lewat outbox untuk offline support)
  // ---------------------------------------------------------------------------

  /// POST /armada/checklist — catat (create/update) checklist harian.
  /// Diperluas dengan solar, ODO, jam operasional (Section 21).
  /// Menggunakan outbox: kalau offline, data masuk antrean dan dikirim
  /// otomatis saat kembali online.
  Future<bool> submitChecklist({
    required String armadaId,
    required bool kondisiBaik,
    String? itemBermasalah,
    double? solarLiter,
    double? odoKm,
    double? jamOperasional,
    List<Map<String, dynamic>>? itemDetails,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.armadaChecklist,
      payloadJson: {},
      payloadData: {
        'armada_id': armadaId,
        'kondisi_baik': kondisiBaik,
        if (itemBermasalah != null && itemBermasalah.trim().isNotEmpty)
          'item_bermasalah': itemBermasalah.trim(),
        if (solarLiter != null) 'solar_liter': solarLiter,
        if (odoKm != null) 'odo_km': odoKm,
        if (jamOperasional != null) 'jam_operasional': jamOperasional,
        if (itemDetails != null) 'items': itemDetails,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    return result.delivered;
  }

  /// POST /armada/odo-awal-proyek — input sekali per armada per proyek.
  /// Menggunakan outbox untuk offline support.
  Future<bool> submitOdoAwalProyek({
    required String armadaId,
    required String titikId,
    required double odoAwal,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.armadaOdoAwal,
      payloadJson: {},
      payloadData: {
        'armada_id': armadaId,
        'titik_id': titikId,
        'odo_awal': odoAwal,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    return result.delivered;
  }

  /// POST /armada/helper/{helperId}/presensi — PIC absenkan helper.
  /// [tipe] adalah 'check_in' atau 'check_out'. [photoPath] wajib.
  /// Menggunakan outbox untuk offline support.
  Future<bool> submitHelperPresensi({
    required String helperId,
    required String tipe,
    required String photoPath,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.helperPresensi,
      payloadJson: {
        'helper_id': helperId,
        'tipe': tipe,
      },
      photoLocalPath: photoPath,
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    return result.delivered;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parser daftar item dari `{ items: [...] }`.
  static List<T> Function(Object? raw) _parseList<T>(
      T Function(Map<String, dynamic>) fromJson) {
    return (raw) {
      final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      final items = map['items'];
      return <T>[
        if (items is List)
          for (final e in items)
            fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    };
  }
}
