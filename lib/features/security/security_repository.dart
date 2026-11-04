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
import 'models/security_models.dart';

/// Repository modul Security (Section 27, TD-F).
/// Mengelola Buku Tamu, Checklist Kantor, Laporan Darurat, dan Verifikasi Ritase Security.
class SecurityRepository {
  SecurityRepository({
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
  // Buku Tamu (TD-F2)
  // ---------------------------------------------------------------------------

  /// GET /security/buku-tamu/hari-ini
  Future<List<BukuTamuRecord>> getBukuTamuHariIni() async {
    try {
      final res = await _api.get<List<BukuTamuRecord>>(
        '/security/buku-tamu/hari-ini',
        parse: (raw) {
          final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
          final list = map['items'] is List
              ? map['items'] as List
              : (raw is List ? raw : const []);
          return list
              .whereType<Map>()
              .map((e) => BukuTamuRecord.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        },
      );
      return res.data ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Submit Tamu Baru (TD-F2).
  Future<void> submitBukuTamu({
    required String nama,
    required int jumlahOrang,
    required String asal,
    String? nomorTelepon,
    required KendaraanTamu kendaraan,
    String? platNomor,
    String? fotoPath,
    String? catatan,
  }) async {
    final clientUuid = _uuid.v4();
    final idempotencyKey = _uuid.v4();

    final payload = <String, String>{
      'nama': nama,
      'jumlah_orang': jumlahOrang.toString(),
      'asal': asal,
      if (nomorTelepon != null && nomorTelepon.isNotEmpty)
        'nomor_telepon': nomorTelepon,
      'kendaraan': kendaraan.name,
      if (platNomor != null && platNomor.isNotEmpty)
        'plat_nomor': platNomor.toUpperCase(),
      if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
      'jam_masuk': DateTime.now().toIso8601String(),
    };

    final action = PendingAction(
      id: clientUuid,
      clientUuid: clientUuid,
      idempotencyKey: idempotencyKey,
      endpoint: PendingEndpoint.securityBukuTamuCreate,
      payloadJson: payload,
      photoLocalPath: fotoPath,
      createdAt: DateTime.now(),
      status: PendingStatus.pending,
    );

    await _outbox.enqueue(action, _sync.send);
  }

  /// Tandai Tamu Keluar (TD-F2).
  Future<void> tandaiKeluarBukuTamu(String tamuId) async {
    final clientUuid = _uuid.v4();
    final idempotencyKey = _uuid.v4();

    final payload = <String, dynamic>{
      'tamu_id': tamuId,
      'jam_keluar': DateTime.now().toIso8601String(),
    };

    final action = PendingAction(
      id: clientUuid,
      clientUuid: clientUuid,
      idempotencyKey: idempotencyKey,
      endpoint: PendingEndpoint.securityBukuTamuKeluar,
      payloadJson: const {},
      payloadData: payload,
      createdAt: DateTime.now(),
      status: PendingStatus.pending,
    );

    await _outbox.enqueue(action, _sync.send);
  }

  // ---------------------------------------------------------------------------
  // Checklist Kantor (TD-F3)
  // ---------------------------------------------------------------------------

  /// Submit Checklist Pemantauan Kantor (TD-F3).
  Future<void> submitChecklistKantor({
    required String periode, // 'harian_siang' | 'malam' | 'custom'
    required String jamPantau,
    required List<ChecklistKantorItem> items,
    String? catatan,
    List<String> fotoPaths = const [],
  }) async {
    final clientUuid = _uuid.v4();
    final idempotencyKey = _uuid.v4();

    final payload = <String, String>{
      'periode': periode,
      'jam_pantau': jamPantau,
      'items': jsonEncode(items.map((i) => i.toJson()).toList()),
      if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
    };

    final action = PendingAction(
      id: clientUuid,
      clientUuid: clientUuid,
      idempotencyKey: idempotencyKey,
      endpoint: PendingEndpoint.securityChecklistSubmit,
      payloadJson: payload,
      photoLocalPaths: fotoPaths,
      createdAt: DateTime.now(),
      status: PendingStatus.pending,
    );

    await _outbox.enqueue(action, _sync.send);
  }

  // ---------------------------------------------------------------------------
  // Laporan Darurat (TD-F4)
  // ---------------------------------------------------------------------------

  /// Submit Laporan Darurat (TD-F4) — offline-first & kirim cepat.
  Future<void> submitLaporanDarurat({
    required String kategori,
    required String judul,
    required String deskripsi,
    required String lokasiRuangan,
    required String tingkat, // 'siaga' | 'darurat' | 'kritis'
    List<String> fotoPaths = const [],
  }) async {
    final clientUuid = _uuid.v4();
    final idempotencyKey = _uuid.v4();

    final payload = <String, String>{
      'kategori': kategori,
      'judul': judul,
      'deskripsi': deskripsi,
      'lokasi_ruangan': lokasiRuangan,
      'tingkat': tingkat,
      'created_at': DateTime.now().toIso8601String(),
    };

    final action = PendingAction(
      id: clientUuid,
      clientUuid: clientUuid,
      idempotencyKey: idempotencyKey,
      endpoint: PendingEndpoint.securityLaporanDarurat,
      payloadJson: payload,
      photoLocalPaths: fotoPaths,
      createdAt: DateTime.now(),
      status: PendingStatus.pending,
    );

    await _outbox.enqueue(action, _sync.send);
  }

  // ---------------------------------------------------------------------------
  // Verifikasi Ritase Security (TD-E4 & TD-F5)
  // ---------------------------------------------------------------------------

  /// Mengambil daftar ritase yang sudah diverifikasi Logistik dan siap konfirmasi Security.
  Future<List<RitaseItem>> getRitaseVerifiedLogistik() async {
    try {
      final res = await _api.get<List<RitaseItem>>(
        '/security/ritase/antrean',
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
      if (res.data != null && res.data!.isNotEmpty) return res.data!;
    } catch (_) {}

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
              .where((r) => r.isVerifiedLogistik || r.wajibJembatanTimbang == true)
              .toList();
        },
      );
      return res.data ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Verifikasi Keamanan Ritase oleh Security (TD-E4).
  Future<void> submitVerifikasiRitaseSecurity({
    required String ritaseId,
    required bool unitSesuai,
    required bool muatanAman,
    String? fotoPath,
    String? catatan,
  }) async {
    final clientUuid = _uuid.v4();
    final idempotencyKey = _uuid.v4();

    final payload = <String, String>{
      'ritase_id': ritaseId,
      'tahap': 'security',
      'status': 'terverifikasi',
      'checklist': jsonEncode({
        'unit_sesuai': unitSesuai,
        'muatan_aman': muatanAman,
      }),
      if (catatan != null && catatan.isNotEmpty) 'catatan': catatan,
    };

    final action = PendingAction(
      id: clientUuid,
      clientUuid: clientUuid,
      idempotencyKey: idempotencyKey,
      endpoint: PendingEndpoint.securityVerifikasiRitase,
      payloadJson: payload,
      photoLocalPath: fotoPath,
      createdAt: DateTime.now(),
      status: PendingStatus.pending,
    );

    await _outbox.enqueue(action, _sync.send);
  }
}

/// Provider SecurityRepository.
final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return SecurityRepository(
    api: ref.watch(apiClientProvider),
    outbox: ref.watch(outboxRepositoryProvider),
    sync: ref.watch(outboxSyncServiceProvider),
  );
});

/// Provider daftar Buku Tamu hari ini.
final bukuTamuHariIniProvider =
    FutureProvider.autoDispose<List<BukuTamuRecord>>((ref) async {
      final repo = ref.watch(securityRepositoryProvider);
      return repo.getBukuTamuHariIni();
    });

/// Provider ritase antrean Security.
final ritaseSecurityAntreanProvider =
    FutureProvider.autoDispose<List<RitaseItem>>((ref) async {
      final repo = ref.watch(securityRepositoryProvider);
      return repo.getRitaseVerifiedLogistik();
    });
