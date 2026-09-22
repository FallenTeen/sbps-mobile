/// Model & pure-logic ritase/muatan — docs/api-mobile.md §Armada, Section 21.4.
///
/// Satu record = satu pengiriman POST /armada/ritase/input. Record punya
/// status per-record (draft/queued/synced/failed) supaya partial failure
/// terlihat dan bisa di-retry secara independen. Business rule ritase
/// tidak diubah: payload wire tetap `{armada_id, jumlah_rit, satuan_volume,
/// catatan?, odo_per_trip?}`.
library;

import '../../core/outbox/pending_action.dart';
import '../../core/json_num.dart';

/// Status pengiriman satu record muatan.
///
/// - [draft]:  tersimpan lokal, belum ada percobaan kirim;
/// - [queued]: sudah masuk outbox, belum ada konfirmasi sukses dari server
///   (queued ≠ server success);
/// - [synced]: server menerima (aksi outbox sudah dibuang);
/// - [failed]: tetap menunggu di outbox tapi butuh retry manual / perbaikan.
enum RitaseRecordStatus {
  draft('Draft'),
  queued('Menunggu sinkron'),
  synced('Dikirim'),
  failed('Gagal');

  const RitaseRecordStatus(this.label);

  final String label;
}

/// Satu catatan muatan.
///
/// [armadaId] adalah sumber kebenaran unit; [armadaPlat]/[armadaJenis] adalah
/// snapshot ringan supaya tile tetap readable walau GET /armada/saya sedang
/// gagal. [clientUuid] dipakai sebagai kunci idempotency + kunci korelasi ke
/// aksi outbox saat reconcile status per record.
class RitaseRecord {
  RitaseRecord({
    required this.id,
    required this.index,
    required this.armadaId,
    required this.jumlah,
    required this.satuan,
    required this.createdAt,
    this.armadaPlat,
    this.armadaJenis,
    this.isAlatBerat = false,
    this.titikId,
    this.proyekId,
    this.catatan,
    this.odoPerTrip,
    this.status = RitaseRecordStatus.draft,
    this.errorMessage,
    this.clientUuid = '',
    this.idempotencyKey = '',
  });

  /// UUID lokal stabil — identitas record untuk edit/delete/status.
  final String id;

  /// Nomor urut tampilan (#1, #2, ...).
  final int index;

  final String armadaId;
  final String? armadaPlat;
  final String? armadaJenis;
  final bool isAlatBerat;
  final String? titikId;
  final String? proyekId;
  final int jumlah;

  /// Satuan tampilan (rit, trip, ton, m³, kg, ...).
  final String satuan;

  final String? catatan;

  /// Odometer per trip (km) — dikirim sebagai `odo_per_trip` bila diisi.
  final double? odoPerTrip;

  final DateTime createdAt;

  RitaseRecordStatus status;
  String? errorMessage;
  final String clientUuid;
  final String idempotencyKey;

  /// Record yang sudah dikirim ke server tidak boleh diedit/dihapus lagi
  /// dari sisi app (data sudah menjadi source of truth di server).
  bool get isLocalEditable => status != RitaseRecordStatus.synced;

  /// True bila siap dikirim (payload lengkap).
  bool get isComplete => armadaId.isNotEmpty && jumlah > 0;

  /// Nilai wire `satuan_volume` — mapping DIJAGA persis seperti versi lama
  /// (business rule tidak diubah).
  String get satuanVolume => switch (satuan) {
    'ton' => 'tonase',
    'm³' => 'm3',
    _ => 'ritase',
  };

  /// Payload POST /armada/ritase/input. `odo_per_trip` dikirim hanya bila
  /// field dipakai. `catatan` kosong tidak dikirim.
  Map<String, dynamic> toPayload() {
    final cat = catatan;
    final odo = odoPerTrip;
    final titik = titikId;
    final proyek = proyekId;
    return {
      'armada_id': armadaId,
      'jumlah_rit': jumlah,
      'satuan_volume': satuanVolume,
      if (titik != null && titik.trim().isNotEmpty) 'titik_id': titik.trim(),
      if (proyek != null && proyek.trim().isNotEmpty) 'proyek_id': proyek.trim(),
      if (cat != null && cat.trim().isNotEmpty) 'catatan': cat.trim(),
      'odo_per_trip': ?odo,
    };
  }

  RitaseRecord copyWith({
    RitaseRecordStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) => RitaseRecord(
    id: id,
    index: index,
    armadaId: armadaId,
    armadaPlat: armadaPlat,
    armadaJenis: armadaJenis,
    isAlatBerat: isAlatBerat,
    titikId: titikId,
    proyekId: proyekId,
    jumlah: jumlah,
    satuan: satuan,
    catatan: catatan,
    odoPerTrip: odoPerTrip,
    createdAt: createdAt,
    status: status ?? this.status,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    clientUuid: clientUuid,
    idempotencyKey: idempotencyKey,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'index': index,
    'armada_id': armadaId,
    'armada_plat': armadaPlat,
    'armada_jenis': armadaJenis,
    'is_alat_berat': isAlatBerat,
    'titik_id': titikId,
    'proyek_id': proyekId,
    'jumlah': jumlah,
    'satuan': satuan,
    'catatan': catatan,
    'odo_per_trip': odoPerTrip,
    'created_at': createdAt.toIso8601String(),
    'status': status.name,
    'error_message': errorMessage,
    'client_uuid': clientUuid,
    'idempotency_key': idempotencyKey,
  };

  factory RitaseRecord.fromJson(Map<String, dynamic> json) => RitaseRecord(
    id: json['id']?.toString() ?? '',
    index: parseInt(json['index']) ?? 0,
    armadaId: json['armada_id']?.toString() ?? '',
    armadaPlat: json['armada_plat']?.toString(),
    armadaJenis: json['armada_jenis']?.toString(),
    isAlatBerat: json['is_alat_berat'] == true,
    titikId: json['titik_id']?.toString(),
    proyekId: json['proyek_id']?.toString(),
    jumlah: parseInt(json['jumlah']) ?? 0,
    satuan: json['satuan']?.toString() ?? 'rit',
    catatan: json['catatan']?.toString(),
    odoPerTrip: parseNum(json['odo_per_trip']),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now(),
    status: RitaseRecordStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => RitaseRecordStatus.draft,
    ),
    errorMessage: json['error_message']?.toString(),
    clientUuid: json['client_uuid']?.toString() ?? '',
    idempotencyKey: json['idempotency_key']?.toString() ?? '',
  );
}

/// Total per satuan untuk index "Muatan Hari Ini".
///
/// Total SATUAN TIDAK dijumlahkan lintas satuan yang berbeda supaya
/// tidak menyesatkan (mis. 6 rit + 3 ton ≠ 9). Grup per satuan.
class RitaseSatuanTotal {
  const RitaseSatuanTotal({
    required this.satuan,
    required this.recordCount,
    required this.total,
  });

  final String satuan;
  final int recordCount;
  final int total;
}

/// Ringkasan index "Muatan Hari Ini".
class RitaseSummary {
  const RitaseSummary({
    required this.recordCount,
    required this.unitCount,
    required this.bySatuan,
    required this.draftCount,
    required this.queuedCount,
    required this.syncedCount,
    required this.failedCount,
  });

  final int recordCount;

  /// Banyak unit berbeda yang terkait (jawaban "unit terkait" pada index).
  final int unitCount;

  /// Total per satuan (tidak menyesatkan karena tidak dijumlah lintas satuan).
  final List<RitaseSatuanTotal> bySatuan;

  final int draftCount;
  final int queuedCount;
  final int syncedCount;
  final int failedCount;

  bool get hasPending => queuedCount > 0 || failedCount > 0;

  bool get allSynced =>
      recordCount > 0 && syncedCount == recordCount && !hasPending;

  /// Label satuan aman untuk satu kartu, mis. "8 rit · 3 ton".
  String get satuanLabel => bySatuan
      .map((b) => '${b.total} ${b.satuan}')
      .join(' · ');

  /// Banyak satuan berbeda yang dipakai.
  int get satuanCount => bySatuan.length;
}

/// Hitung ringkasan dari daftar record tanpa mengubah business rule.
RitaseSummary summaryRitase(List<RitaseRecord> records) {
  final bySatuan = <String, RitaseSatuanTotal>{};
  final units = <String>{};
  var draft = 0;
  var queued = 0;
  var synced = 0;
  var failed = 0;

  for (final r in records) {
    units.add(r.armadaId);
    final prev = bySatuan[r.satuan];
    bySatuan[r.satuan] = RitaseSatuanTotal(
      satuan: r.satuan,
      recordCount: (prev?.recordCount ?? 0) + 1,
      total: (prev?.total ?? 0) + r.jumlah,
    );
    switch (r.status) {
      case RitaseRecordStatus.draft:
        draft++;
      case RitaseRecordStatus.queued:
        queued++;
      case RitaseRecordStatus.synced:
        synced++;
      case RitaseRecordStatus.failed:
        failed++;
    }
  }

  return RitaseSummary(
    recordCount: records.length,
    unitCount: units.length,
    bySatuan: [...bySatuan.values],
    draftCount: draft,
    queuedCount: queued,
    syncedCount: synced,
    failedCount: failed,
  );
}

/// Reconcile status record terhadap isi outbox saat ini.
///
/// Prinsip: aksi outbox yang sudah tidak ada = sudah diterima server
/// (outbox menghapus aksi hanya saat delivered) → tandai `synced`.
/// Record `draft`/`synced` tidak disentuh.
///
/// [pendingByClientUuid] dipetakan dari `client_uuid` aksi → status aksi.
RitaseRecord reconcileRecordStatus(
  RitaseRecord record,
  Map<String, PendingStatus> pendingByClientUuid,
) {
  if (record.status == RitaseRecordStatus.synced ||
      record.status == RitaseRecordStatus.draft) {
    return record;
  }
  if (record.clientUuid.isEmpty) return record;

  final actionStatus = pendingByClientUuid[record.clientUuid];
  if (actionStatus == null) {
    return record.copyWith(
      status: RitaseRecordStatus.synced,
      clearError: true,
    );
  }
  if (actionStatus == PendingStatus.failed) {
    return record.copyWith(status: RitaseRecordStatus.failed);
  }
  return record.copyWith(status: RitaseRecordStatus.queued);
}