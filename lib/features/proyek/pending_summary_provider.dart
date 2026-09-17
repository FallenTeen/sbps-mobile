import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/outbox/outbox_repository.dart';
import '../../core/outbox/pending_action.dart';
import '../presensi/presensi_providers.dart';

/// Provider untuk ringkasan jumlah item pending per modul.
///
/// Menggunakan [OutboxRepository] yang sudah dibagikan (via
/// [outboxRepositoryProvider]) supaya tidak membuat instance
/// terpisah setiap kali dibaca. Cache di internal [PendingSummary]
/// dibersihkan secara periodik (TTL 2 detik) sehingga
/// data tetap diperbarui tanpa membaca Hive berulang kali.
///
/// Saat outbox berubah, cache berikutnya yang di-ttl expired
/// akan membaca ulang. Pola ini cukup karena badge/pending
/// item tidak butuh real-time detik-detik — pembaruan dalam
/// ~2 detik setelah aksi (check-in, submit, dll.) sudah
/// memadai untuk UX di lapangan.
final pendingSummaryProvider = Provider.autoDispose<PendingSummary>((ref) {
  final repo = ref.read(outboxRepositoryProvider);
  return PendingSummary(repository: repo);
});

class PendingSummary {
  PendingSummary({required OutboxRepository repository})
      : _repository = repository;

  final OutboxRepository _repository;

  /// Cache hasil pembacaan terakhir supaya tidak membaca Hive
  /// berulang dalam satu frame yang sama.
  List<PendingAction>? _cachedActions;
  DateTime? _cachedAt;

  static const _cacheTtl = Duration(seconds: 2);

  Future<ModulePendingCounts> getSummary(String role) async {
    final now = DateTime.now();
    if (_cachedActions == null || now.difference(_cachedAt!) > _cacheTtl) {
      _cachedActions = await _repository.pendingActions();
      _cachedAt = now;
    }

    final actions = _cachedActions!;

    // --- Armada: checklist harian, ODO awal, helper presensi, ritase,
    // checklist major, dan ajuan servis (driver mengajukan via form). ---
    final armadaCount = actions.where(
      (a) =>
          a.endpoint == PendingEndpoint.armadaChecklist ||
          a.endpoint == PendingEndpoint.armadaOdoAwal ||
          a.endpoint == PendingEndpoint.helperPresensi ||
          a.endpoint == PendingEndpoint.armadaRitase ||
          a.endpoint == PendingEndpoint.armadaChecklistMajor ||
          a.endpoint == PendingEndpoint.servisAjuan,
    ).length;

    // --- Produksi: mulai & selesai sesi ---
    final produksiCount = actions.where(
      (a) =>
          a.endpoint == PendingEndpoint.produksiMulai ||
          a.endpoint == PendingEndpoint.produksiSelesai,
    ).length;

    // --- QC: slump test & uji tekan ---
    final qcCount = actions.where(
      (a) =>
          a.endpoint == PendingEndpoint.qcSlumpTest ||
          a.endpoint == PendingEndpoint.qcUjiTekan,
    ).length;

    // --- Workshop: mulai, selesai, foto bukti todo, request sparepart. ---
    final workshopCount = actions.where(
      (a) =>
          a.endpoint == PendingEndpoint.workshopMulai ||
          a.endpoint == PendingEndpoint.workshopSelesai ||
          a.endpoint == PendingEndpoint.workshopTodoPhoto ||
          a.endpoint == PendingEndpoint.workshopRequestSparepart,
    ).length;

    // --- Inventory: opname ---
    final inventoryCount = actions.where(
      (a) => a.endpoint == PendingEndpoint.inventoryOpname,
    ).length;

    // --- Formulir lapangan ---
    final formulirCount = actions.where(
      (a) => a.endpoint == PendingEndpoint.formulirSubmit,
    ).length;

    // --- Upload media ---
    final uploadCount = actions.where(
      (a) => a.endpoint == PendingEndpoint.uploadMedia,
    ).length;

    // --- Presensi: check-in & check-out ---
    final presensiCount = actions.where(
      (a) =>
          a.endpoint == PendingEndpoint.presensiCheckIn ||
          a.endpoint == PendingEndpoint.presensiCheckOut,
    ).length;

    final counts = ModulePendingCounts(
      armada: _canAccessArmada(role) ? armadaCount : 0,
      produksi: _canAccessProduksi(role) ? produksiCount : 0,
      workshop: _canAccessWorkshop(role) ? workshopCount : 0,
      qc: _canAccessQC(role) ? qcCount : 0,
      inventory: _canAccessInventory(role) ? inventoryCount : 0,
      formulir: _canAccessFormulir(role) ? formulirCount : 0,
      upload: _canAccessUpload(role) ? uploadCount : 0,
      presensi: _canAccessPresensi(role) ? presensiCount : 0,
    );

    return counts;
  }

  bool _canAccessArmada(String role) => [
        'Driver Armada',
        'Kepala Divisi Armada',
        'Ketua Divisi Armada',
        'Ketua Armada',
        'Owner',
        'Admin Keuangan',
      ].contains(role);

  bool _canAccessProduksi(String role) =>
      ['Mandor Titik', 'Owner', 'Operator Mesin'].contains(role);

  bool _canAccessWorkshop(String role) =>
      ['Workshop', 'Owner'].contains(role);

  bool _canAccessQC(String role) =>
      ['Mandor Titik', 'Owner', 'Operator Mesin'].contains(role);

  bool _canAccessInventory(String role) =>
      ['Inventory', 'Owner', 'Mandor Titik'].contains(role);

  bool _canAccessFormulir(String role) =>
      ['Driver Armada', 'Mandor Titik', 'Owner', 'Operator Mesin'].contains(role);

  bool _canAccessUpload(String role) =>
      ['Owner', 'Admin Keuangan'].contains(role);

  bool _canAccessPresensi(String role) => true;
}

/// Jumlah item pending yang perlu dikerjakan, per modul.
class ModulePendingCounts {
  const ModulePendingCounts({
    this.armada = 0,
    this.produksi = 0,
    this.workshop = 0,
    this.qc = 0,
    this.inventory = 0,
    this.formulir = 0,
    this.upload = 0,
    this.presensi = 0,
  });

  final int armada;
  final int produksi;
  final int workshop;
  final int qc;
  final int inventory;
  final int formulir;
  final int upload;
  final int presensi;

  int get total =>
      armada + produksi + workshop + qc + inventory + formulir + upload + presensi;

  bool get hasPending => total > 0;
}