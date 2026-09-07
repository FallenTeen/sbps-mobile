import '../../core/api_client.dart';
import 'models/armada.dart';

/// Repository modul Armada (driver) — docs/api-mobile.md §Armada.
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
  Future<void> submitChecklist({
    required String armadaId,
    required bool kondisiBaik,
    String? itemBermasalah,
  }) async {
    await _api.post<Object?>(
      '/armada/checklist',
      body: {
        'armada_id': armadaId,
        'kondisi_baik': kondisiBaik,
        if (itemBermasalah != null && itemBermasalah.trim().isNotEmpty)
          'item_bermasalah': itemBermasalah.trim(),
      },
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
