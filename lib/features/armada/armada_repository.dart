import 'dart:convert';

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
  }) : _api = api,
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
    return res.data ?? [];
  }

  /// GET /armada/pengisian-solar?armada_id=&tanggal= — riwayat pengisian.
  Future<List<PengisianSolarItem>> getPengisianSolar({
    String? armadaId,
    String? tanggal,
  }) async {
    final res = await _api.get<List<PengisianSolarItem>>(
      '/armada/pengisian-solar',
      query: {
        if (armadaId != null && armadaId.isNotEmpty) 'armada_id': armadaId,
        if (tanggal != null && tanggal.isNotEmpty) 'tanggal': tanggal,
      },
      parse: _parseList<PengisianSolarItem>(PengisianSolarItem.fromJson),
    );
    return res.data ?? [];
  }

  /// GET /armada/odo-awal-proyek?armada_id= — riwayat ODO awal proyek.
  Future<List<OdoAwalProyekItem>> getOdoAwalProyek({String? armadaId}) async {
    final res = await _api.get<List<OdoAwalProyekItem>>(
      '/armada/odo-awal-proyek',
      query: {
        if (armadaId != null && armadaId.isNotEmpty) 'armada_id': armadaId,
      },
      parse: _parseList<OdoAwalProyekItem>(OdoAwalProyekItem.fromJson),
    );
    return res.data ?? [];
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

  /// POST /armada/checklist/awal (multipart) — checklist awal hari ini.
  /// [items] berisi `{bagian, kondisi, catatan?, foto?}`.
  /// [fotoStokSolarPath]/[fotoOdoPagiPath] wajib saat pembuatan pertama.
  Future<bool> submitChecklistAwal({
    required String armadaId,
    required List<Map<String, dynamic>> items,
    required String stokSolar,
    double? odoPagi,
    double? hmOdo,
    String? jamMulaiOperasi,
    String? fotoStokSolarPath,
    String? fotoOdoPagiPath,
    String? clientUuid,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: clientUuid ?? _uuid.v4(),
      endpoint: PendingEndpoint.armadaChecklistAwal,
      payloadJson: {
        'armada_id': armadaId,
        ..._itemFields(items),
        'stok_solar': stokSolar,
        if (odoPagi != null) 'odo_pagi': _numStr(odoPagi),
        if (hmOdo != null) 'hm_odo': _numStr(hmOdo),
        if (jamMulaiOperasi != null && jamMulaiOperasi.isNotEmpty)
          'jam_mulai_operasi': jamMulaiOperasi,
      },
      photoFields: {
        if (fotoStokSolarPath != null && fotoStokSolarPath.isNotEmpty)
          'foto_stok_solar': fotoStokSolarPath,
        if (fotoOdoPagiPath != null && fotoOdoPagiPath.isNotEmpty)
          'foto_odo_pagi': fotoOdoPagiPath,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(
        result.errorMessage ?? 'Gagal menyimpan checklist awal.',
      );
    }
    return result.delivered;
  }

  /// POST /armada/checklist/akhir (multipart) — checklist akhir (final).
  Future<bool> submitChecklistAkhir({
    required String armadaId,
    required List<Map<String, dynamic>> items,
    required String stokSolar,
    double? odoAkhir,
    double? hmAkhir,
    String? jamSelesaiOperasi,
    String? fotoStokSolarPath,
    String? fotoOdoAkhirPath,
    String? clientUuid,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: clientUuid ?? _uuid.v4(),
      endpoint: PendingEndpoint.armadaChecklistAkhir,
      payloadJson: {
        'armada_id': armadaId,
        ..._itemFields(items),
        'stok_solar': stokSolar,
        if (odoAkhir != null) 'odo_akhir': _numStr(odoAkhir),
        if (hmAkhir != null) 'hm_akhir': _numStr(hmAkhir),
        if (jamSelesaiOperasi != null && jamSelesaiOperasi.isNotEmpty)
          'jam_selesai_operasi': jamSelesaiOperasi,
      },
      photoFields: {
        if (fotoStokSolarPath != null && fotoStokSolarPath.isNotEmpty)
          'foto_stok_solar': fotoStokSolarPath,
        if (fotoOdoAkhirPath != null && fotoOdoAkhirPath.isNotEmpty)
          'foto_odo_akhir': fotoOdoAkhirPath,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(
        result.errorMessage ?? 'Gagal menyimpan checklist akhir.',
      );
    }
    return result.delivered;
  }

  /// POST /armada/pengisian-solar (multipart) — catat satu pengisian solar.
  /// [fotoOdoPath] dan [fotoNotaPath] wajib.
  Future<bool> submitPengisianSolar({
    required String armadaId,
    required double odoAtauHm,
    required double liter,
    required double nominalRp,
    required String fotoOdoPath,
    required String fotoNotaPath,
    String? tanggal,
    String? catatan,
    String? clientUuid,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: clientUuid ?? _uuid.v4(),
      endpoint: PendingEndpoint.armadaPengisianSolar,
      payloadJson: {
        'armada_id': armadaId,
        'odo_atau_hm': _numStr(odoAtauHm),
        'liter': _numStr(liter),
        'nominal_rp': _numStr(nominalRp),
        if (tanggal != null && tanggal.isNotEmpty) 'tanggal': tanggal,
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
      },
      photoFields: {
        'foto_odo': fotoOdoPath,
        'foto_nota': fotoNotaPath,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(
        result.errorMessage ?? 'Gagal menyimpan pengisian solar.',
      );
    }
    return result.delivered;
  }

  /// POST /armada/checklist-major — serah terima kendaraan (Section 21.10).
  /// Menggunakan outbox untuk offline support. [items] berupa daftar peta
  /// `{label, status, photo_index?}`; [photoPaths] berisi path foto item
  /// (urutan sesuai `photo_index`), dikirim sebagai field multipart `photos[]`.
  Future<OutboxSendResult> submitChecklistMajor({
    required String armadaId,
    required List<Map<String, dynamic>> items,
    String? catatan,
    List<String> photoPaths = const [],
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.armadaChecklistMajor,
      payloadJson: {
        'armada_id': armadaId,
        'items': jsonEncode(items),
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
      },
      payloadData: const {},
      photoLocalPaths: photoPaths,
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    return _outbox.enqueue(action, _sync.send);
  }

  /// POST /armada/odo-awal-proyek — input sekali per armada per proyek.
  /// Menggunakan outbox untuk offline support.
  Future<bool> submitOdoAwalProyek({
    required String armadaId,
    String? titikId,
    String? proyekId,
    required double odoAwal,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: _uuid.v4(),
      endpoint: PendingEndpoint.armadaOdoAwal,
      payloadJson: {},
      payloadData: {
        'armada_id': armadaId,
        if (titikId != null && titikId.trim().isNotEmpty)
          'titik_id': titikId.trim(),
        if (proyekId != null && proyekId.trim().isNotEmpty)
          'proyek_id': proyekId.trim(),
        'odo_awal': odoAwal,
      },
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(result.errorMessage ?? 'Gagal menyimpan ODO awal.');
    }
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
      payloadJson: {'helper_id': helperId, 'tipe': tipe},
      photoLocalPath: photoPath,
      createdAt: DateTime.now(),
      idempotencyKey: _uuid.v4(),
    );

    final result = await _outbox.enqueue(action, _sync.send);
    if (result.permanentlyFailed) {
      throw ApiException(result.errorMessage ?? 'Gagal mencatat presensi helper.');
    }
    return result.delivered;
  }

  /// POST /armada/ritase/input — satu catatan muatan via outbox.
  ///
  /// [clientUuid] & [idempotencyKey] opsional: bila diisi dipakai persis
  /// (retry memakai nilai yang sama → server idempotent). Default: uuid baru.
  Future<OutboxSendResult> submitRitase({
    required String armadaId,
    required int jumlahRit,
    required String satuanVolume,
    String? titikId,
    String? proyekId,
    String? catatan,
    double? odoPerTrip,
    String? clientUuid,
    String? idempotencyKey,
  }) async {
    final action = PendingAction(
      id: _uuid.v4(),
      clientUuid: clientUuid ?? _uuid.v4(),
      endpoint: PendingEndpoint.armadaRitase,
      payloadJson: {},
      payloadData: {
        'armada_id': armadaId,
        'jumlah_rit': jumlahRit,
        'satuan_volume': satuanVolume,
        if (titikId != null && titikId.trim().isNotEmpty)
          'titik_id': titikId.trim(),
        if (proyekId != null && proyekId.trim().isNotEmpty)
          'proyek_id': proyekId.trim(),
        if (catatan != null && catatan.trim().isNotEmpty)
          'catatan': catatan.trim(),
        'odo_per_trip': ?odoPerTrip,
      },
      createdAt: DateTime.now(),
      idempotencyKey: idempotencyKey ?? _uuid.v4(),
    );

    return _outbox.enqueue(action, _sync.send);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parser daftar item dari `{ items: [...] }`.
  static List<T> Function(Object? raw) _parseList<T>(
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return (raw) {
      final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
      final items = map['items'];
      return <T>[
        if (items is List)
          for (final e in items) fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    };
  }

  /// Ubah daftar item checklist menjadi form field bracket-notation
  /// (`items[0][bagian]`, dst.) agar Laravel mem-parse sebagai array.
  static Map<String, String> _itemFields(
    List<Map<String, dynamic>> items,
  ) {
    final fields = <String, String>{};
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      fields['items[$i][bagian]'] = it['bagian']?.toString() ?? '';
      fields['items[$i][kondisi]'] = it['kondisi']?.toString() ?? 'baik';
      final catatan = it['catatan']?.toString() ?? '';
      if (catatan.isNotEmpty) fields['items[$i][catatan]'] = catatan;
      final foto = it['foto']?.toString() ?? '';
      if (foto.isNotEmpty) fields['items[$i][foto]'] = foto;
    }
    return fields;
  }

  /// Format angka untuk field multipart (bulat tanpa desimal).
  static String _numStr(double n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toString();
}
