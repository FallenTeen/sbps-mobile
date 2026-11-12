import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_config.dart';
import 'location_buffer_service.dart';
import 'models.dart';

class TrackingIsolateUpload {
  static void resetForTest() {
    _flushing = false;
  }

  TrackingIsolateUpload._();

  static const _storage = FlutterSecureStorage();
  static const _uuid = Uuid();
  static const _maxBatch = 450;
  static bool _flushing = false;

  static Future<void> flush({Dio? client, String? token, String? role}) async {
    if (_flushing) return;
    if (await LocationBufferService.isAuthBlocked()) return;
    final gotLock = await LocationBufferService.tryAcquireFlushLock();
    if (!gotLock) return;
    _flushing = true;
    try {
      final resolvedToken = token ?? await _storage.read(key: 'auth_token');
      if (resolvedToken == null || resolvedToken.isEmpty) return;

      final resolvedRole = role ?? await _storage.read(key: 'active_role');

      await LocationBufferService.pruneStaleIsolate();

      var pending = await LocationBufferService.readPendingBatchIsolate();
      List<TrackPoint> points;
      String batchId;

      if (pending != null) {
        if (pending.points.length > _maxBatch) {
          final chunk = pending.points.take(_maxBatch).toList();
          await LocationBufferService.savePendingBatchIsolate(
            pending.batchId,
            chunk,
          );
          batchId = pending.batchId;
          points = chunk;
        } else {
          batchId = pending.batchId;
          points = pending.points;
        }
      } else {
        points = await LocationBufferService.snapshotIsolate();
        if (points.isEmpty) return;
        points = points.take(_maxBatch).toList();
        batchId = _uuid.v4();
        await LocationBufferService.savePendingBatchIsolate(batchId, points);
      }
      if (points.isEmpty) {
        await LocationBufferService.clearPendingBatchIsolate();
        return;
      }

      final dio = client ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.requiredApiBaseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 60),
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $resolvedToken',
                if (resolvedRole != null && resolvedRole.isNotEmpty)
                  'X-Active-Role': resolvedRole,
                'X-Device-Type': 'android',
              },
              validateStatus: (status) => status != null && status < 500,
            ),
          );

      final ownClient = client == null;
      try {
        final res = await dio.post<Map<String, dynamic>>(
          '/tracking/batch',
          data: {
            'batch_id': batchId,
            'locations': [for (final p in points) p.toApiJson()],
          },
        );
        final status = res.statusCode ?? 0;
        if (status == 401) {
          await LocationBufferService.setAuthBlocked(const Duration(hours: 1));
          return;
        }
        if (status >= 200 && status < 300) {
          await LocationBufferService.removeByIdsIsolate(
            points.map((p) => p.id).toSet(),
          );
          await LocationBufferService.clearPendingBatchIsolate();
          await LocationBufferService.clearAuthBlocked();
        }
      } on DioException {
        // Jaringan gagal: batch dipertahankan untuk retry.
      } catch (_) {
        // Abaikan error tak terduga.
      } finally {
        if (ownClient) dio.close();
      }
    } finally {
      _flushing = false;
      await LocationBufferService.releaseFlushLock();
    }
  }
}
