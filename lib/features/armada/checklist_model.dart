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

/// Kekurangan dokumentasi satu bagian saat validasi submit.
enum ChecklistDocGap {
  /// Lengkap atau tidak relevan (kondisi baik).
  none,

  /// Level belum dipilih.
  belumDiperiksa,

  /// Bermasalah tapi catatan kosong.
  catatanKosong,

  /// Rusak tanpa foto kerusakan (wajib).
  rusakTanpaFoto,

  /// Perlu perhatian tanpa foto kondisi (wajib).
  perluPerhatianTanpaFoto,
}

/// Gap dokumentasi satu bagian checklist untuk validasi submit.
///
/// Urutan prioritas cek di sisi pemanggil: belum diperiksa, catatan kosong,
/// rusak tanpa foto, perlu perhatian tanpa foto. Foto wajib untuk SEMUA
/// kondisi bermasalah (perlu perhatian dan rusak).
ChecklistDocGap checklistBagianGap(
  ChecklistItemLevel? level,
  String catatan,
  String? fotoPath,
) {
  if (level == null) return ChecklistDocGap.belumDiperiksa;
  if (!level.isBermasalah) return ChecklistDocGap.none;
  if (catatan.trim().isEmpty) return ChecklistDocGap.catatanKosong;
  if (fotoPath == null || fotoPath.isEmpty) {
    return level == ChecklistItemLevel.rusak
        ? ChecklistDocGap.rusakTanpaFoto
        : ChecklistDocGap.perluPerhatianTanpaFoto;
  }
  return ChecklistDocGap.none;
}

/// Indeks pertama dengan level null, atau null bila semua sudah diisi.
int? firstUnfilledLevelIndex(List<ChecklistItemLevel?> levels) {
  for (var i = 0; i < levels.length; i++) {
    if (levels[i] == null) return i;
  }
  return null;
}

/// Index accordion yang terbuka setelah user memilih [level] pada bagian
/// [index]. Item bermasalah TIDAK lanjut otomatis: form dokumentasi
/// (catatan + foto) harus langsung terlihat di item tersebut. Item baik
/// lanjut ke bagian berikutnya yang belum diperiksa.
int? nextExpandedIndexAfterLevel({
  required int index,
  required ChecklistItemLevel level,
  required List<ChecklistItemLevel?> levels,
}) => level.isBermasalah ? index : firstUnfilledLevelIndex(levels);

/// Payload satu item checklist untuk submit: `catatan`/`foto` hanya ikut
/// bila kondisi bermasalah. Item baik tidak mengirim dokumentasi lama
/// (nilai tetap tersimpan di form/draft, hanya difilter dari payload).
Map<String, dynamic> checklistItemPayload({
  required String bagian,
  required ChecklistItemLevel level,
  String catatan = '',
  String? fotoPath,
}) => {
  'bagian': bagian,
  'kondisi': level.wireValue,
  if (level.isBermasalah && catatan.trim().isNotEmpty)
    'catatan': catatan.trim(),
  if (level.isBermasalah && fotoPath != null && fotoPath.isNotEmpty)
    'foto': fotoPath,
};

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