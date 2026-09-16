/// Model Checklist Major — Serah Terima Kendaraan (Section 21.10).
///
/// Logika murni (tanpa Flutter) supaya gampang diuji: status per item,
/// progres penilaian, ringkasan kondisi, bukti foto, dan snapshot
/// "berangkat" untuk perbandingan mode kembali. Status yang dikirim ke server
/// PERSIS sesuai API: `baik`, `rusak_ringan`, `rusak_berat`.
library;

/// Status penilaian satu item checklist major.
enum MajorChecklistStatus {
  /// Belum dinilai (awal; tidak dikirim ke server).
  belum('', 'Belum dinilai'),

  baik('baik', 'Baik'),
  rusakRingan('rusak_ringan', 'Rusak Ringan'),
  rusakBerat('rusak_berat', 'Rusak Berat');

  const MajorChecklistStatus(this.wire, this.label);

  /// Nilai yang dikirim ke endpoint `/armada/checklist-major`.
  final String wire;

  /// Label user-facing.
  final String label;

  bool get isAssessed => this != belum;
  bool get isRusak => this == rusakRingan || this == rusakBerat;
}

/// Ten item serah terima kendaraan (urutan & label tetap).
const List<String> kMajorChecklistLabels = [
  'Body / Karoseri',
  'Mesin',
  'Transmisi',
  'Rem',
  'Ban',
  'Kaca / Spion',
  'Lampu',
  'Interior',
  'KM (Odometer)',
  'Kelengkapan Dokumen',
];

/// Satu item checklist major pada form.
class MajorChecklistItem {
  const MajorChecklistItem({
    required this.index,
    required this.label,
    this.status = MajorChecklistStatus.belum,
    this.photoPath,
  });

  /// Nomor urut 1-based untuk tampilan "01", "02", dst.
  final int index;
  final String label;
  final MajorChecklistStatus status;

  /// Path foto bukti (dari watermarked camera / galeri). Opsional.
  final String? photoPath;

  /// Bukti foto relevan bila status tidak baik (rusak ringan/berat).
  bool get needsEvidence => status.isRusak;

  MajorChecklistItem copyWith({
    MajorChecklistStatus? status,
    String? photoPath,
    bool clearPhoto = false,
  }) {
    return MajorChecklistItem(
      index: index,
      label: label,
      status: status ?? this.status,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    );
  }

  /// Representasi payload item ke server: `{label, status, photo_index?}`.
  Map<String, dynamic> toPayload() => {
    'label': label,
    'status': status.wire,
  };
}

/// Membuat daftar default 10 item checklist (belum dinilai).
List<MajorChecklistItem> defaultMajorChecklistItems() {
  return [
    for (var i = 0; i < kMajorChecklistLabels.length; i++)
      MajorChecklistItem(index: i + 1, label: kMajorChecklistLabels[i]),
  ];
}

/// Jumlah item yang sudah dinilai ("X / 10 dinilai").
int majorAssessedCount(List<MajorChecklistItem> items) =>
    items.where((i) => i.status.isAssessed).length;

/// Semua item sudah dinilai.
bool majorAllAssessed(List<MajorChecklistItem> items) =>
    items.isNotEmpty && items.every((i) => i.status.isAssessed);

/// Semua item rusak sudah punya bukti foto.
bool majorEvidenceComplete(List<MajorChecklistItem> items) =>
    items.where((i) => i.needsEvidence).every(
      (i) => i.photoPath != null && i.photoPath!.trim().isNotEmpty,
    );

/// Bisa submit: semua dinilai DAN semua item rusak punya bukti foto.
bool majorCanSubmit(List<MajorChecklistItem> items) =>
    majorAllAssessed(items) && majorEvidenceComplete(items);

/// Ringkasan kondisi untuk layar Review: "9 Baik / 1 Rusak Ringan / ...".
class MajorChecklistSummary {
  const MajorChecklistSummary({
    this.baik = 0,
    this.rusakRingan = 0,
    this.rusakBerat = 0,
  });

  final int baik;
  final int rusakRingan;
  final int rusakBerat;

  int get totalAssessed => baik + rusakRingan + rusakBerat;

  /// Catatan layak-kondisi: tidak baik bila ada item rusak.
  bool get allBaik => rusakRingan == 0 && rusakBerat == 0;

  /// Baris ringkas: "9 Baik • 1 Rusak Ringan • 0 Rusak Berat".
  String get line => '$baik Baik • $rusakRingan Rusak Ringan • $rusakBerat Rusak Berat';
}

/// Menghitung ringkasan dari daftar item (hanya yang sudah dinilai).
MajorChecklistSummary majorSummaryOf(List<MajorChecklistItem> items) {
  var baik = 0, ringan = 0, berat = 0;
  for (final i in items) {
    switch (i.status) {
      case MajorChecklistStatus.baik:
        baik++;
      case MajorChecklistStatus.rusakRingan:
        ringan++;
      case MajorChecklistStatus.rusakBerat:
        berat++;
      case MajorChecklistStatus.belum:
        break;
    }
  }
  return MajorChecklistSummary(
    baik: baik,
    rusakRingan: ringan,
    rusakBerat: berat,
  );
}

/// Mode serah terima: berangkat (penyerahan awal) atau kembali (pengembalian).
enum MajorChecklistMode { berangkat, kembali }

extension MajorChecklistModeX on MajorChecklistMode {
  String get label => this == MajorChecklistMode.berangkat ? 'Berangkat' : 'Kembali';
  String get subLabel =>
      this == MajorChecklistMode.berangkat
          ? 'Serah terima awal / penyerahan unit'
          : 'Pengembalian unit — bandingkan dengan kondisi berangkat';
}

/// Snapshot kondisi "berangkat" tersimpan lokal per armada.
///
/// Dipakai sebagai basis perbandingan saat mode "kembali" — tidak mengarang
/// endpoint baru; disimpan lokal dari submit berangkat terakhir di perangkat ini.
class MajorChecklistSnapshot {
  const MajorChecklistSnapshot({
    required this.armadaId,
    required this.tanggal,
    required this.items,
  });

  final String armadaId;

  /// Tanggal & waktu submit berangkat (ISO).
  final String tanggal;

  /// Pasangan (label, status berangkat).
  final List<({String label, MajorChecklistStatus status})> items;

  Map<String, dynamic> toJson() => {
    'armada_id': armadaId,
    'tanggal': tanggal,
    'items': [
      for (final i in items)
        {'label': i.label, 'status': i.status.name},
    ],
  };

  static MajorChecklistSnapshot fromJson(Map<String, dynamic> json) {
    final list = json['items'];
    return MajorChecklistSnapshot(
      armadaId: json['armada_id']?.toString() ?? '',
      tanggal: json['tanggal']?.toString() ?? '',
      items: [
        if (list is List)
          for (final e in list)
            if (e is Map)
              (
                label:
                    (e['label']?.toString() ?? ''),
                status: MajorChecklistStatus.values.asNameMap()[
                      e['status']?.toString()
                    ] ??
                    MajorChecklistStatus.belum,
              ),
      ],
    );
  }

  /// Status berangkat untuk [label] (null bila tidak tercatat).
  MajorChecklistStatus? statusFor(String label) {
    for (final i in items) {
      if (i.label == label) return i.status;
    }
    return null;
  }
}

/// Selisih satu item antara kondisi berangkat & kini (mode kembali).
class MajorItemComparison {
  const MajorItemComparison({
    required this.label,
    required this.berangkat,
    required this.kini,
  });

  final String label;

  /// Kondisi saat berangkat (null bila snapshot tidak tersedia).
  final MajorChecklistStatus? berangkat;
  final MajorChecklistStatus kini;

  /// Berubah menjadi buruk: berangkat baik lalu kini rusak, atau
  /// kondisi kini lebih buruk dari berangkat.
  bool get berubah =>
      berangkat != null &&
      berangkat != kini &&
      (kini.isRusak || !berangkat!.isRusak);
}

/// Membandingkan kondisi kini (mode kembali) dengan snapshot berangkat.
///
/// Mengembalikan daftar perbandingan per label — dipakai pada layar Review
/// bila mode kembali & snapshot tersedia. [snapshot] null → otomatis
/// dianggap tidak ada data berangkat.
List<MajorItemComparison> compareReturnToBerangkat(
  List<MajorChecklistItem> kini, {
  MajorChecklistSnapshot? snapshot,
}) {
  return [
    for (final item in kini)
      MajorItemComparison(
        label: item.label,
        berangkat: snapshot?.statusFor(item.label),
        kini: item.status,
      ),
  ];
}