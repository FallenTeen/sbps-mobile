import '../../core/api_client.dart';
import 'models/armada.dart';
import 'models/helper.dart';

/// Repository modul Armada (driver) — docs/api-mobile.md §Armada
/// dan manual-book Section 21.
class ArmadaRepository {
  ArmadaRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

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

  /// POST /armada/checklist — catat (create/update) checklist harian.
  /// Diperluas dengan solar, ODO, jam operasional (Section 21).
  Future<void> submitChecklist({
    required String armadaId,
    required bool kondisiBaik,
    String? itemBermasalah,
    double? solarLiter,
    double? odoKm,
    double? jamOperasional,
  }) async {
    await _api.post<Object?>(
      '/armada/checklist',
      body: {
        'armada_id': armadaId,
        'kondisi_baik': kondisiBaik,
        if (itemBermasalah != null && itemBermasalah.trim().isNotEmpty)
          'item_bermasalah': itemBermasalah.trim(),
        'solar_liter': ?solarLiter,
        'odo_km': ?odoKm,
        'jam_operasional': ?jamOperasional,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // ODO Awal Proyek (Section 21)
  // ---------------------------------------------------------------------------

  /// POST /armada/odo-awal-proyek — input sekali per armada per proyek.
  Future<void> submitOdoAwalProyek({
    required String armadaId,
    required String titikId,
    required double odoAwal,
  }) async {
    await _api.post<Object?>(
      '/armada/odo-awal-proyek',
      body: {
        'armada_id': armadaId,
        'titik_id': titikId,
        'odo_awal': odoAwal,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Presensi (Section 21)
  // ---------------------------------------------------------------------------

  /// GET /armada/helper — daftar helper untuk PIC aktif.
  Future<List<Helper>> getHelpers() async {
    final res = await _api.get<List<Helper>>(
      '/armada/helper',
      parse: _parseList<Helper>(Helper.fromJson),
    );
    return res.data ?? const [];
  }

  /// POST /armada/helper/{helperId}/presensi — PIC absenkan helper.
  /// [tipe] adalah 'check_in' atau 'check_out'. [photoPath] wajib.
  Future<void> submitHelperPresensi({
    required String helperId,
    required String tipe,
    required String photoPath,
  }) async {
    await _api.postMultipart<Object?>(
      '/armada/helper/$helperId/presensi',
      fields: {'tipe': tipe},
      files: [MultipartFileSpec('photo', photoPath)],
    );
  }

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

