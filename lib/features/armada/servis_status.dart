/// Status & alur Servis Armada — source of truth label/aksi/kronologi.
///
/// Semua layar (index / work queue, detail, form) memakai helper ini supaya
/// tidak ada label atau urutan timeline yang terpecah antar file.
/// Status yang dipakai PERSIS sesuai API (`models/servis_armada.dart`):
/// `diajukan`, `disetujui`, `ditolak`, `dikerjakan`, `selesai`.
library;

import 'package:flutter/material.dart';

import 'models/servis_armada.dart';

/// Urutan status work queue (tanpa 'ditolak'; ditolak jadi node terminal).
const List<String> kServisStatusOrder = [
  'diajukan',
  'disetujui',
  'dikerjakan',
  'selesai',
];

const List<String> kKategoriServisOptions = [
  'rutin',
  'kerusakan',
  'darurat',
  'ganti_oli',
];

/// Label user-facing kategori servis.
String formatKategoriServis(String k) {
  return switch (k) {
    'rutin' => 'Servis Rutin / Berkala',
    'kerusakan' => 'Perbaikan Kerusakan',
    'darurat' => 'Darurat / Mogok',
    'ganti_oli' => 'Ganti Oli / Pelumas',
    _ => k,
  };
}

/// Label user-facing status servis.
String servisStatusLabel(String status) {
  return switch (status) {
    'diajukan' => 'Menunggu Persetujuan',
    'disetujui' => 'Disetujui',
    'dikerjakan' => 'Sedang Dikerjakan',
    'selesai' => 'Selesai',
    'ditolak' => 'Ditolak',
    _ => status,
  };
}

/// Warna status servis (index, kartu, detail).
Color servisStatusColor(String status) {
  return switch (status) {
    'diajukan' => Colors.orange,
    'disetujui' => Colors.blue,
    'dikerjakan' => Colors.purple,
    'selesai' => Colors.green,
    'ditolak' => Colors.red,
    _ => Colors.grey,
  };
}

/// Role yang bisa melakukan approval servis (Kepala/Ketua Divisi Armada + admin).
bool canApproveServis(String? role) {
  return role == 'Owner' ||
      role == 'Admin Keuangan' ||
      role == 'Kepala Divisi Armada' ||
      role == 'Ketua Divisi Armada' ||
      role == 'Ketua Armada' ||
      role == 'Admin';
}

/// Label aksi berikutnya pada kartu work queue, sesuai status saat ini.
String servisNextAction(ServisArmada item, {bool canApprove = false}) {
  return switch (item.status) {
    'diajukan' => canApprove
        ? 'Perlu persetujuan — buka untuk Setujui / Tolak'
        : 'Menunggu persetujuan atasan',
    'disetujui' => 'Menunggu dijadwalkan workshop',
    'dikerjakan' => 'Sedang dikerjakan workshop',
    'selesai' => 'Selesai — lihat hasil & biaya servis',
    'ditolak' => 'Ditolak — ajukan ulang bila perlu',
    _ => '',
  };
}

/// Tahapan timeline servis.
enum ServisTimelineState { done, current, pending, rejected }

/// Satu node pada timeline servis.
class ServisTimelineStep {
  const ServisTimelineStep({
    required this.label,
    required this.state,
    this.caption,
  });

  final String label;
  final ServisTimelineState state;
  final String? caption;
}

/// Membangun langkah timeline: Diajukan → Disetujui → Dikerjakan → Selesai.
///
/// - status aktif = `current`; yang sudah lewat = `done`; yang belum = `pending`.
/// - `ditolak` = node terminal merah setelah Diajukan (dengan alasan penolakan).
List<ServisTimelineStep> servisTimelineSteps(ServisArmada item) {
  const labels = ['Diajukan', 'Disetujui', 'Dikerjakan', 'Selesai'];
  final reachedIdx = kServisStatusOrder.indexOf(item.status);

  if (item.status == 'ditolak') {
    return [
      for (var i = 0; i < labels.length; i++)
        ServisTimelineStep(
          label: labels[i],
          state: i == 0 ? ServisTimelineState.done : ServisTimelineState.pending,
        ),
      ServisTimelineStep(
        label: 'Ditolak',
        state: ServisTimelineState.rejected,
        caption: item.alasanPenolakan,
      ),
    ];
  }

  return [
    for (var i = 0; i < labels.length; i++)
      ServisTimelineStep(
        label: labels[i],
        state: item.status == 'selesai'
            ? ServisTimelineState.done
            : i < reachedIdx
                ? ServisTimelineState.done
                : i == reachedIdx
                    ? ServisTimelineState.current
                    : ServisTimelineState.pending,
      ),
  ];
}