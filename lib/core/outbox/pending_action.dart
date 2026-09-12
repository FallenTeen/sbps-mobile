import 'dart:convert';

/// Jenis endpoint untuk aksi offline di outbox.
enum PendingEndpoint {
  presensiCheckIn('/presensi/check-in'),
  presensiCheckOut('/presensi/check-out'),
  formulirSubmit('/formulir/submit'),
  produksiMulai('/produksi/mulai'),
  produksiSelesai('/produksi/selesai'),
  qcSlumpTest('/qc/slump-test'),
  qcUjiTekan('/qc/uji-tekan'),
  uploadMedia('/upload'),
  helperPresensi('/armada/helper'),
  armadaChecklist('/armada/checklist'),
  armadaOdoAwal('/armada/odo-awal-proyek'),
  armadaRitase('/armada/ritase/input'),
  workshopMulai('/servis-armada/{id}/mulai'),
  workshopSelesai('/servis-armada/{id}/selesai'),
  inventoryOpname('/inventory/opname');

  const PendingEndpoint(this.path);

  final String path;

  /// Endpoint JSON (body JSON, tanpa lampiran file).
  bool get isJson =>
      this == produksiMulai ||
      this == produksiSelesai ||
      this == qcSlumpTest ||
      this == qcUjiTekan ||
      this == armadaChecklist ||
      this == armadaOdoAwal ||
      this == armadaRitase ||
      this == workshopMulai ||
      this == workshopSelesai ||
      this == inventoryOpname;

  /// Endpoint multipart generik `POST /upload` dengan field `files[]`
  /// (1-10 file, docs/api-mobile.md §11.1). `client_uuid` dikirim sebagai
  /// FORM FIELD — sync service menyuntikkannya dari [PendingAction.clientUuid].
  bool get isUploadMedia => this == uploadMedia;
}

/// Status sinkronisasi satu aksi outbox.
enum PendingStatus { pending, syncing, success, failed }

/// Satu aksi presensi yang menunggu dikirim ke server.
///
/// Disimpan sebagai peta JSON di Hive box `outbox` — foto TIDAK disimpan
/// sebagai base64, hanya path file lokal di [photoLocalPath].
///
/// [idempotencyKey] dikirim ulang PERSIS sama pada setiap percobaan
/// (middleware Idempotency-Key backend mengembalikan respons asli saat
/// retry — lihat docs/api-mobile.md bagian Idempotency).
class PendingAction {
  PendingAction({
    required this.id,
    required this.clientUuid,
    required this.endpoint,
    required this.payloadJson,
    this.payloadData = const <String, dynamic>{},
    required this.createdAt,
    required this.idempotencyKey,
    this.photoLocalPath,
    this.photoLocalPaths = const [],
    this.status = PendingStatus.pending,
    this.lastAttemptAt,
    this.retryCount = 0,
    this.errorMessage,
  });

  final String id;

  /// UUID v4 unik per aksi — tidak boleh dipakai ulang antar aksi.
  final String clientUuid;

  final PendingEndpoint endpoint;

  /// Field form multipart, mis. `{titik_id, latitude, longitude, device_id}`.
  final Map<String, String> payloadJson;

  /// Body JSON untuk endpoint non-multipart ([PendingEndpoint.isJson]),
  /// mis. sesi produksi. `client_uuid` TIDAK perlu diisi di sini —
  /// sync service menyuntikkannya dari [clientUuid] saat kirim.
  final Map<String, dynamic> payloadData;

  final String? photoLocalPath;

  /// Banyak file sekaligus (formulir lapangan: `photos[]`, maks 5).
  final List<String> photoLocalPaths;

  PendingStatus status;

  DateTime createdAt;
  DateTime? lastAttemptAt;
  int retryCount;
  String? errorMessage;

  final String idempotencyKey;

  Map<String, dynamic> toJson() => {
        'id': id,
        'client_uuid': clientUuid,
        'endpoint': endpoint.name,
        'payload_json': payloadJson,
        'payload_data': payloadData,
        'photo_local_path': photoLocalPath,
        'photo_local_paths': photoLocalPaths,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'last_attempt_at': lastAttemptAt?.toIso8601String(),
        'retry_count': retryCount,
        'error_message': errorMessage,
        'idempotency_key': idempotencyKey,
      };

  static PendingAction fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] as String,
      clientUuid: json['client_uuid'] as String,
      endpoint: PendingEndpoint.values
          .firstWhere((e) => e.name == json['endpoint']),
      payloadJson: Map<String, String>.from(
          (json['payload_json'] as Map?) ?? const {}),
      payloadData: Map<String, dynamic>.from(
          (json['payload_data'] as Map?) ?? const {}),
      photoLocalPath: json['photo_local_path'] as String?,
      photoLocalPaths: (json['photo_local_paths'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: PendingStatus.values
          .firstWhere((s) => s.name == json['status'], orElse: () => PendingStatus.pending),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastAttemptAt: json['last_attempt_at'] == null
          ? null
          : DateTime.parse(json['last_attempt_at'] as String),
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      errorMessage: json['error_message'] as String?,
      idempotencyKey: json['idempotency_key'] as String,
    );
  }

  String encode() => jsonEncode(toJson());

  static PendingAction decode(String raw) =>
      PendingAction.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
}
