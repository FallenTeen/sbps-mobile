// Status & alur Servis Armada - source of truth label/aksi/kronologi.
///
/// Semua layar (index / work queue, detail, form) memakai helper ini supaya
/// tidak ada label atau urutan timeline yang terpecah antar file.
/// Status yang dipakai PERSIS sesuai API (`models/servis_armada.dart`):
/// `diajukan`, `disetujui`, `ditolak`, `dikerjakan`, `menunggu_sparepart`,
/// `sparepart_tersedia`, `selesai`.
library;

import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import 'models/servis_armada.dart';

/// Urutan status timeline servis (sama dengan `ServisTimelineService` backend).
const List<String> kServisStatusOrder = [
  'diajukan',
  'disetujui',
  'dikerjakan',
  'menunggu_sparepart',
  'sparepart_tersedia',
  'selesai',
];

const List<String> kServisTimelineLabels = [
  'Ajuan Dibuat',
  'Persetujuan',
  'Pengerjaan Dimulai',
  'Menunggu Sparepart',
  'Sparepart Tersedia',
  'Servis Selesai',
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
    'menunggu_sparepart' => 'Menunggu Sparepart',
    'sparepart_tersedia' => 'Sparepart Tersedia',
    'selesai' => 'Selesai',
    'ditolak' => 'Ditolak',
    _ => status,
  };
}

/// Warna status servis (index, kartu, detail).
/// Token tema (bukan Material raw) supaya ikut dark mode.
Color servisStatusColor(String status, AppColors colors) {
  return switch (status) {
    'diajukan' => colors.warning,
    'disetujui' => colors.info,
    'dikerjakan' => colors.secondary,
    'menunggu_sparepart' => colors.warning,
    'sparepart_tersedia' => colors.info,
    'selesai' => colors.success,
    'ditolak' => colors.error,
    _ => colors.textMuted,
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
        ? 'Perlu persetujuan - buka untuk Setujui / Tolak'
        : 'Menunggu persetujuan atasan',
    'disetujui' => 'Menunggu dijadwalkan workshop',
    'dikerjakan' => 'Sedang dikerjakan workshop',
    'menunggu_sparepart' => 'Menunggu sparepart dari inventory',
    'sparepart_tersedia' => 'Sparepart tersedia - lanjutkan pengerjaan',
    'selesai' => 'Selesai - lihat hasil & biaya servis',
    'ditolak' => 'Ditolak - ajukan ulang bila perlu',
    _ => '',
  };
}

/// Tahapan timeline servis.
enum ServisTimelineState { done, current, pending, skipped, rejected }

/// Satu node pada timeline servis.
class ServisTimelineStep {
  const ServisTimelineStep({
    required this.label,
    required this.state,
    this.caption,
    this.badge,
  });

  final String label;
  final ServisTimelineState state;
  final String? caption;
  final String? badge;
}

/// Fallback lokal bila endpoint detail belum mengirim `timeline`.
/// Urutan mengikuti backend 6 step; sparepart dilewati bila `butuh_sparepart=false`.
List<ServisTimelineStep> servisTimelineSteps(ServisArmada item) {
  final rejected = item.status == 'ditolak';
  final reachedIdx = kServisStatusOrder.indexOf(item.status);
  final skipSparepart = !item.butuhSparepart &&
      (item.status == 'dikerjakan' || item.status == 'selesai');

  return [
    for (var i = 0; i < kServisTimelineLabels.length; i++)
      ServisTimelineStep(
        label: kServisTimelineLabels[i],
        badge: rejected && i == 1
            ? 'Ditolak'
            : skipSparepart &&
                    (kServisStatusOrder[i] == 'menunggu_sparepart' ||
                        kServisStatusOrder[i] == 'sparepart_tersedia')
                ? 'Tidak perlu'
                : null,
        caption: rejected && i == 1 ? item.alasanPenolakan : null,
        state: rejected
            ? i == 0
                ? ServisTimelineState.done
                : i == 1
                    ? ServisTimelineState.rejected
                    : ServisTimelineState.pending
            : skipSparepart &&
                    (kServisStatusOrder[i] == 'menunggu_sparepart' ||
                        kServisStatusOrder[i] == 'sparepart_tersedia')
                ? ServisTimelineState.skipped
                : item.status == 'selesai'
                    ? ServisTimelineState.done
                    : i < reachedIdx
                        ? ServisTimelineState.done
                        : i == reachedIdx
                            ? ServisTimelineState.current
                            : ServisTimelineState.pending,
      ),
  ];
}
