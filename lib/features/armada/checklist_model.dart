/// Model & pure-logic checklist harian armada — docs/api-mobile.md §Armada,
/// Section 21. Business rule tetap dua kondisi (`kondisi_baik` / bukan baik);
/// tiga level item di bawah hanyalah pembeda kualitas input dari sisi app.
library;

import 'models/armada.dart';

/// Tingkat kondisi satu item checklist.
///
/// Wire `baik` dipetakan dengan cara yang backward-compatible: `status` dan
/// `catatan` bersifat additive, sedangkan `baik` tetap memakai aturan lama.
enum ChecklistItemLevel {
  baik('Baik'),
  perluPerhatian('Perlu Perhatian'),
  rusak('Rusak / Tidak Aman');

  const ChecklistItemLevel(this.label);

  final String label;

  /// Nilai wire untuk payload item.
  String get wireValue => switch (this) {
    ChecklistItemLevel.baik => 'baik',
    ChecklistItemLevel.perluPerhatian => 'perlu_perhatian',
    ChecklistItemLevel.rusak => 'rusak',
  };

  /// True jika bukan kondisi baik mentah (termasuk perlu perhatian).
  bool get isBermasalah => this != ChecklistItemLevel.baik;
}

/// Satu item checklist yang sedang diisi di form.
class ChecklistItemDraft {
  const ChecklistItemDraft({
    required this.label,
    this.level = ChecklistItemLevel.baik,
    this.photoPath,
    this.catatan = '',
  });

  final String label;
  final ChecklistItemLevel level;
  final String? photoPath;
  final String catatan;

  ChecklistItemDraft copyWith({
    ChecklistItemLevel? level,
    String? photoPath,
    String? catatan,
  }) => ChecklistItemDraft(
    label: label,
    level: level ?? this.level,
    photoPath: photoPath ?? this.photoPath,
    catatan: catatan ?? this.catatan,
  );

  /// Payload item untuk POST /armada/checklist (field `items`).
  Map<String, dynamic> toPayload() => {
    'label': label,
    'baik': !level.isBermasalah,
    'status': level.wireValue,
    if (catatan.trim().isNotEmpty) 'catatan': catatan.trim(),
    if (photoPath != null) 'has_foto': true,
  };
}

/// Status agregat satu unit pada index checklist (task queue).
enum ChecklistUnitStatus { menunggu, selesai, bermasalah }

/// Klasifikasi unit: belum dicek = menunggu; sudah dicek tapi ada yang tidak
/// baik = bermasalah; sudah dicek dan dianggap baik = selesai.
ChecklistUnitStatus unitChecklistStatus(ArmadaChecklist item) {
  if (!item.sudahIsi) return ChecklistUnitStatus.menunggu;
  return item.kondisiBaik == false
      ? ChecklistUnitStatus.bermasalah
      : ChecklistUnitStatus.selesai;
}

/// Filter tab pada index checklist.
enum ChecklistFilterK {
  semua('Semua'),
  belumDicek('Belum Dicek'),
  bermasalah('Bermasalah'),
  selesai('Selesai');

  const ChecklistFilterK(this.label);

  final String label;
}

/// Terapkan filter ke daftar unit checklist hari ini.
List<ArmadaChecklist> applyChecklistFilter(
  List<ArmadaChecklist> items,
  ChecklistFilterK filter,
) {
  return switch (filter) {
    ChecklistFilterK.semua => items,
    ChecklistFilterK.belumDicek => items
        .where((i) => !i.sudahIsi)
        .toList(),
    ChecklistFilterK.selesai => items
        .where((i) => i.sudahIsi && i.kondisiBaik != false)
        .toList(),
    ChecklistFilterK.bermasalah => items
        .where((i) => i.sudahIsi && i.kondisiBaik == false)
        .toList(),
  };
}

/// Ringkasan progress checklist hari ini untuk header work queue.
class ChecklistSummary {
  const ChecklistSummary({
    required this.total,
    required this.checked,
    required this.menunggu,
    required this.bermasalah,
  });

  final int total;

  /// Sudah diperiksa hari ini (selesai baik maupun bermasalah).
  final int checked;
  final int menunggu;
  final int bermasalah;

  double get progressRatio =>
      total == 0 ? 0.0 : checked / total;
}

/// Hitung ringkasan dari daftar unit checklist hari ini.
ChecklistSummary checklistSummary(List<ArmadaChecklist> items) {
  var selesai = 0;
  var bermasalah = 0;
  for (final i in items) {
    if (!i.sudahIsi) continue;
    if (i.kondisiBaik == false) {
      bermasalah++;
    } else {
      selesai++;
    }
  }
  final checked = selesai + bermasalah;
  return ChecklistSummary(
    total: items.length,
    checked: checked,
    menunggu: items.length - checked,
    bermasalah: bermasalah,
  );
}

/// Perbandingan bacaan ODO/HM (sebelumnya vs sekarang) untuk tampil
/// previous/current/delta serta warning ketika nilainya menurun.
class OdoReading {
  const OdoReading({this.previous, this.current});

  /// Nilai tercatat sebelumnya (draft/server), bisa null.
  final double? previous;

  /// Nilai input pengguna saat ini, bisa null bila belum diisi.
  final double? current;

  bool get hasBoth => previous != null && current != null;

  /// Selisih absolut (pemakaian) bila kedua nilai tersedia.
  double? get delta =>
      hasBoth ? (current! - previous!).abs() : null;

  /// True bila nilai sekarang lebih kecil dari sebelumnya (ODO/HM turun).
  bool get decreased => hasBoth && current! < previous!;

  /// Label pemakaian: "+70 km", "+2 jam", atau null bila tak valid.
  String? pemakaianLabel(bool isAlatBerat) {
    final d = delta;
    if (d == null) return null;
    final angka = d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
    return '+$angka ${isAlatBerat ? 'jam' : 'km'}';
  }
}