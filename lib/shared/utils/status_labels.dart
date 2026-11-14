import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// Label status & peran yang ramah user (PERBAIKAN PHASE 18).
//
// Istilah resmi mengikuti docs/api-mobile.md backend; wire-value dari
// server (snake_case/underscore/uppercase) tidak boleh ditampilkan
// mentah ke user.

const Map<String, String> _kStatusLabels = {
  'aktif': 'Aktif',
  'berjalan': 'Berjalan',
  'selesai': 'Selesai',
  'dibatalkan': 'Dibatalkan',
  'pending': 'Pending',
  'lunas': 'Lunas',
  'belum_dibayar': 'Belum Dibayar',
  'dibayar': 'Dibayar',
  'jatuh_tempo': 'Jatuh Tempo',
  'diterima': 'Diterima',
  'ditolak': 'Ditolak',
  'diajukan': 'Diajukan',
  'draft': 'Draft',
};

/// Ubah status wire-value menjadi label human-friendly (title case,
/// underscore diganti spasi). Nilai tak dikenal di-render huruf kapital.
String statusLabel(String status) {
  final lower = status.trim().toLowerCase();
  if (lower.isEmpty) return '-';
  return _kStatusLabels[lower] ?? titleCase(lower);
}

/// Label status proyek kontrak & invoice kontraktor (portal kontraktor).
String kontraktorStatusLabel(String status) => statusLabel(status);

/// Label peran pengirim chat/komunikasi kontraktor.
String kontraktorParticipantLabel(String role) {
  final lower = role.trim().toLowerCase();
  return switch (lower) {
    'kontraktor' => 'Kontraktor',
    'owner' => 'Owner',
    'admin keuangan' => 'Admin Keuangan',
    _ => lower.isEmpty ? '-' : titleCase(lower),
  };
}

/// Warna semantik untuk status apa pun (wire-value maupun nama enum).
///
/// Sumber kebenaran tunggal warna status: menggantikan salinan privat
/// `_statusColor` di berbagai layar. Semantik tetap:
/// success = selesai/terverifikasi, info = berjalan, warning = menunggu
/// tindakan, error = gagal/ditolak, textMuted = tak dikenal.
/// Jangan tambahkan hue baru; tambahkan key baru ke tabel bila perlu.
Color statusColor(String status, BuildContext context) {
  final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
  return switch (status.trim().toLowerCase()) {
    'aktif' ||
    'berjalan' ||
    'lunas' ||
    'selesai' ||
    'dibayar' ||
    'diterima' ||
    'lolos' ||
    'beroperasi' ||
    'tersedia' ||
    'terkirim' ||
    'disetujui' ||
    'synced' ||
    'success' =>
      colors.success,
    'dikerjakan' ||
    'diproses' ||
    'standby' ||
    'siaga' ||
    'syncing' ||
    'ditagih' =>
      colors.info,
    'pending' ||
    'menunggu' ||
    'menunggu_hasil' ||
    'belum_dibayar' ||
    'diajukan' ||
    'draft' ||
    'servis' ||
    'perbaikan' ||
    'maintenance' ||
    'kurang' ||
    'lunas_sebagian' ||
    'menunggu_approval_finance' ||
    'menunggu_approval_owner' ||
    'ditunda' ||
    'queued' =>
      colors.warning,
    'ditolak' ||
    'dibatalkan' ||
    'jatuh_tempo' ||
    'rusak' ||
    'nonaktif' ||
    'tidak_lolos' ||
    'tidak_tersedia' ||
    'failed' ||
    'gagal' =>
      colors.error,
    _ => colors.textMuted,
  };
}

/// Ubah teks apa pun (snake_case) menjadi Title Case.
String titleCase(String value) {
  final words = value
      .trim()
      .toLowerCase()
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '-';
  return words.map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}