import '../../core/api_client.dart';
import 'models.dart';

/// Repository Live Tracking (docs/api-mobile.md §9).
class TrackingRepository {
  TrackingRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// POST /tracking/batch — idempotent via `batch_id` di body: retry
  /// dengan batch_id sama mengembalikan hasil sebelumnya (duplicate:true)
  /// tanpa menduplikasi baris lokasi.
  Future<BatchSendResult> sendBatch({
    required String batchId,
    required List<TrackPoint> points,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/tracking/batch',
      body: {
        'batch_id': batchId,
        'locations': [for (final p in points) p.toApiJson()],
      },
      parse: (raw) =>
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
    final data = res.data ?? const {};
    return BatchSendResult(
      received: (data['received'] as num?)?.toInt() ?? 0,
      saved: (data['saved'] as num?)?.toInt() ?? 0,
      duplicate: data['duplicate'] == true,
    );
  }

  /// GET /tracking/active-users — khusus Owner / Admin Keuangan.
  Future<List<ActiveUser>> getActiveUsers() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/tracking/active-users',
      parse: (raw) =>
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );
    final data = res.data ?? const {};
    final items = data['items'];
    return [
      if (items is List)
        for (final e in items)
          ActiveUser.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
  }

  /// GET /tracking/hari-ini/{userId} — khusus Owner / Admin Keuangan.
  /// 403 = bukan role berwenang; 422 = target tanpa data karyawan.
  Future<TrailData> getHariIni(String userId) async {
    final res = await _api.get<TrailData>(
      '/tracking/hari-ini/$userId',
      parse: TrailData.fromRaw,
    );
    return res.data ?? TrailData(userId: userId);
  }
}

class BatchSendResult {
  const BatchSendResult({
    required this.received,
    required this.saved,
    this.duplicate = false,
  });

  final int received;
  final int saved;
  final bool duplicate;

  bool get complete => received > 0 && saved == received;
}
