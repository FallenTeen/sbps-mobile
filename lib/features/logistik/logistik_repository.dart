import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api_client.dart';
import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/outbox_sync_service.dart';
import '../../core/outbox/pending_action.dart';
import '../armada/models/armada.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';

/// Repository modul Logistik & Timbang (Section 27, TD-E).
/// Mengelola antrean verifikasi ritase, data timbang, dan verifikasi muatan resmi.
class LogistikRepository {
  LogistikRepository({
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

  /// GET /logistik/ritase/antrean atau fallback /armada/ritase
  /// Mengambil daftar ritase yang memerlukan verifikasi muatan & timbang logistik.
  Future<List<RitaseItem>> getAntreanVerifikasi() async {
    try {
      final res = await _api.get<List<RitaseItem>>(
        '/logistik/ritase/antrean',
        parse: (raw) {
          final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
          final list = map['items'] is List
              ? map['items'] as List
              : (raw is List ? raw : const []);
          return list
              .whereType<Map>()
              .map((e) => RitaseItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        },
      );
      if (res.data != null && res.data!.isNotEmpty) {
        return res.data!;
      }
    } catch (_) {
      // Fallback bila endpoint antrean khusus belum aktif
    }

    try {
      final res = await _api.get<List<RitaseItem>>(
        '/armada/ritase',
        query: {'per_page': 50},
        parse: (raw) {
          final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
          final list = map['items'] is List
              ? map['items'] as List
              : (raw is List ? raw : const []);
          return list
              .whereType<Map>()
              .map((e) => RitaseItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        },
      );
      return res.data ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Submit Verifikasi Ritase oleh Logistik (TD-E3).
  Future<void> submitVerifikasiRitase({
    required String ritaseId,
    required double jumlahVerifikasi,
    required double beratKosongKg,
    required double beratIsiKg,
    required double beratNettoKg,
    required bool isTimbangUlang,
    required Map<String, bool> checklist,
    String? nomorTiket,
    String? fotoTiketPath,
    String? catatan,
  }) async {
    final clientUuid = _uuid.v4();
    final idempotencyKey = _uuid.v4();

    final payload = <String, String>{
      'ritase_id': ritaseId,
      'tahap': 'logistik',
      'status': 'terverifikasi',
      'jumlah_verifikasi': jumlahVerifikasi.toString(),
      'berat_kosong_kg': beratKosongKg.toString(),
      'berat_isi_kg': beratIsiKg.toString(),
      'berat_netto_kg': beratNettoKg.toString(),
      'tara_sumber': isTimbangUlang ? 'timbang_ulang' : 'master',
      'checklist': jsonEncode(checklist),
      if (nomorTiket != null && nomorTiket.trim().isNotEmpty)
        'nomor_tiket': nomorTiket.trim(),
      if (catatan != null && catatan.trim().isNotEmpty)
        'catatan': catatan.trim(),
    };

    final action = PendingAction(
      id: clientUuid,
      clientUuid: clientUuid,
      idempotencyKey: idempotencyKey,
      endpoint: PendingEndpoint.logistikVerifikasiRitase,
      payloadJson: payload,
      photoLocalPath: fotoTiketPath,
      createdAt: DateTime.now(),
      status: PendingStatus.pending,
    );

    await _outbox.enqueue(action, _sync.send);
  }
}

/// Provider LogistikRepository.
final logistikRepositoryProvider = Provider<LogistikRepository>((ref) {
  return LogistikRepository(
    api: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    sync: ref.watch(outboxSyncServiceProvider),
  );
});

/// FutureProvider antrean verifikasi ritase logistik.
final antreanVerifikasiRitaseProvider =
    FutureProvider.autoDispose<List<RitaseItem>>((ref) async {
      final repo = ref.watch(logistikRepositoryProvider);
      return repo.getAntreanVerifikasi();
    });
