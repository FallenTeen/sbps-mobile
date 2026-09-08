import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_response.dart';
import '../auth/auth_providers.dart';
import '../presensi/models/titik.dart';

/// Repository untuk fetch data titik peta (GET /api/mobile/titik-map).
class TitikMapRepository {
  TitikMapRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Fetch daftar titik untuk peta interaktif.
  ///
  /// Response backend: `{ status, message, data: { items: [...] } }` atau array langsung.
  /// Berisi: `{ id, nama, latitude, longitude, radius_presensi_meter, proyek_id, proyek_nama, status }`.
  Future<List<Titik>> getTitikMap() async {
    try {
      // TODO: Backend endpoint GET /titik-map (atau /api/mobile/titik-map).
      final res = await _api.get<List<Titik>>(
        '/titik-map',
        parse: (raw) {
          if (raw is Map) {
            final items = raw['items'] ?? raw['data'];
            if (items is List) {
              return items
                  .whereType<Map>()
                  .map((e) => Titik.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }
          } else if (raw is List) {
            return raw
                .whereType<Map>()
                .map((e) => Titik.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
          return const [];
        },
      );

      _ensureSuccess(res);
      return res.data ?? const [];
    } on ApiException catch (e) {
      // Fallback sementara ke /titik-aktif bila endpoint /titik-map belum tersedia di backend (404/501).
      // TODO: Hapus fallback ini setelah endpoint /titik-map sudah live di backend.
      if (e.statusCode == 404 || e.statusCode == 501 || e.statusCode == 405) {
        final fallbackRes = await _api.get<List<Titik>>(
          '/titik-aktif',
          parse: (raw) => raw is List
              ? raw
                  .whereType<Map>()
                  .map((e) => Titik.fromJson(Map<String, dynamic>.from(e)))
                  .toList()
              : const [],
        );
        return fallbackRes.data ?? const [];
      }
      rethrow;
    }
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}

final titikMapRepositoryProvider = Provider<TitikMapRepository>(
  (ref) => TitikMapRepository(api: ref.watch(apiClientProvider)),
);

/// Provider Riverpod untuk data titik peta interaktif.
/// State: `AsyncValue<List<Titik>>` (loading, error, data).
final titikMapProvider = FutureProvider.autoDispose<List<Titik>>(
  (ref) => ref.watch(titikMapRepositoryProvider).getTitikMap(),
);
