/// checklist akhir armada (Armada Driver → step ④) — MODEL SAJA, persiapan.
library;

/// Persiapan struktur data tanpa menunggu backend.
///
/// Status: **pending backend** — field checklist akhir belum tersedia di
/// `GET /armada/saya` maupun endpoint checklist terkait. UI `WorkflowStepper`
/// step ④ sengaja TIDAK diubah sampai endpoint siap (biarkan placeholder).
///
/// Bentuk item sengaja MENGIKUTI shape yang sudah dipakai `POST /armada/checklist`
/// (`items: [{label, baik, has_foto}]`) — reuse struktur existing, bukan bikin
/// struktur data baru. `WorkshopTodoItem` (workshop_models.dart) tidak dipakai
/// karena shape-nya job/todo (`jobId`/`isDone`) dan tidak cocok dengan item
/// pemeriksaan kondisi (`label`/`baik`/foto).
class ChecklistAkhirItem {
  const ChecklistAkhirItem({
    required this.label,
    required this.baik,
    this.hasFoto = false,
    this.photoPath,
  });

  final String label;
  final bool baik;
  final bool hasFoto;
  final String? photoPath;

  /// Bangun dari draft lokal [ChecklistDraftStore] (kunci `label`,
  /// `baik`, `photo_path`).
  factory ChecklistAkhirItem.fromDraft(Map<String, dynamic> draft) {
    final photoPath = draft['photo_path']?.toString();
    return ChecklistAkhirItem(
      label: draft['label']?.toString() ?? '-',
      baik: draft['baik'] != false,
      hasFoto: photoPath != null && photoPath.isNotEmpty,
      photoPath: photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'baik': baik,
    if (hasFoto) 'has_foto': true,
  };
}

/// Satu kiriman "checklist akhir" satu armada — siap dipakai saat endpoint
/// backend checklist akhir dibuka. Belum ada pemanggilan UI (menunggu backend).
class ChecklistAkhir {
  const ChecklistAkhir({
    required this.armadaId,
    required this.items,
    this.kondisiBaik,
    this.itemBermasalah,
    this.solarLiter,
    this.odoKm,
    this.jamOperasional,
    this.submittedAt,
  });

  final String armadaId;
  final List<ChecklistAkhirItem> items;
  final bool? kondisiBaik;
  final String? itemBermasalah;
  final double? solarLiter;
  final double? odoKm;
  final double? jamOperasional;
  final DateTime? submittedAt;

  bool get isSubmitted => submittedAt != null;

  /// Bangun dari draft lokal — shape sama dengan checklist harian; penanda
  /// `submittedAt` mengisi [submittedAt] bila jackpot mark submit ter-set.
  static ChecklistAkhir? fromDraft(
    String armadaId,
    Map<String, dynamic>? draft,
  ) {
    if (draft == null) return null;
    final rawItems = draft['items'];
    return ChecklistAkhir(
      armadaId: armadaId,
      items: [
        if (rawItems is List)
          for (final r in rawItems)
            if (r is Map)
              ChecklistAkhirItem.fromDraft(
                Map<String, dynamic>.from(r),
              ),
      ],
      solarLiter: double.tryParse(draft['solar']?.toString() ?? ''),
      odoKm: double.tryParse(draft['odo']?.toString() ?? ''),
      jamOperasional: double.tryParse(draft['jam']?.toString() ?? ''),
      submittedAt: draft['submittedAt'] == null
          ? null
          : DateTime.tryParse(draft['submittedAt'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'armada_id': armadaId,
    if (kondisiBaik != null) 'kondisi_baik': kondisiBaik,
    if (itemBermasalah != null && itemBermasalah!.trim().isNotEmpty)
      'item_bermasalah': itemBermasalah!.trim(),
    if (solarLiter != null) 'solar_liter': solarLiter,
    if (odoKm != null) 'odo_km': odoKm,
    if (jamOperasional != null) 'jam_operasional': jamOperasional,
    'items': [for (final i in items) i.toJson()],
  };
}