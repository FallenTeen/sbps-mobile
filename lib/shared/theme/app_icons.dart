import 'package:flutter/material.dart';

/// Skala ukuran ikon standar (Rencana §3.3 I4).
///
/// Skala resmi aplikasi: 16 (tooltip/inline), 20 (leading field), 32
/// (prominent/leading lokasi), 64 (empty state). Dipakai agar tidak ada
/// angka magic number berulang di seluruh layar.
abstract final class AppIconSize {
  /// Tooltip, label pendamping teks, step indicator kecil.
  static const double inline = 16;

  /// Leading ikon field list, menu, trailing aksi kecil.
  static const double leading = 20;

  /// Ikon menonjol: leading lokasi, badge, header ringkasan.
  static const double prominent = 32;

  /// Empty / error state.
  static const double emptyState = 64;
}

/// Mapping ikon semantik ke [IconData] aktual (Rencana §3.3 I5).
///
/// Kalau nanti ingin mengganti satu ikon secara global (atau ikon set yang
/// berbeda per dark/light/outdoor mode), cukup ubah di file ini — bukan
/// cari-ganti di puluhan layar.
abstract final class AppIcons {
  // ── Status ──────────────────────────────────────────────────────────────────
  static const statusSuccess = Icons.check_circle_outline;
  static const statusError = Icons.error_outline;
  static const statusWarning = Icons.warning_amber_outlined;
  static const statusInfo = Icons.info_outline;
  static const statusPending = Icons.sync_problem;
  static const statusOffline = Icons.cloud_off_outlined;
  static const statusOnline = Icons.cloud_done_outlined;

  // ── Navigasi ────────────────────────────────────────────────────────────────
  static const navHome = Icons.home_outlined;
  static const navHomeActive = Icons.home_rounded;
  static const navBack = Icons.arrow_back_ios_new_rounded;
  static const navForward = Icons.chevron_right_rounded;
  static const navRefresh = Icons.refresh_rounded;

  // ── Aksi ────────────────────────────────────────────────────────────────────
  static const actionAdd = Icons.add_rounded;
  static const actionCamera = Icons.camera_alt_outlined;
  static const actionDelete = Icons.delete_outline;
  static const actionEdit = Icons.edit_outlined;
  static const actionSubmit = Icons.send_rounded;

  // ── Bidang (domain) ─────────────────────────────────────────────────────────
  static const fieldVehicle = Icons.directions_bus_outlined;
  static const fieldLocation = Icons.location_on_outlined;
  static const fieldCalendar = Icons.calendar_today_outlined;
  static const fieldPhoto = Icons.photo_outlined;
  static const fieldNote = Icons.mode_edit_outline;

  // ── Empty state ─────────────────────────────────────────────────────────────
  static const emptyData = Icons.inbox_outlined;
  static const emptyNoResult = Icons.search_off_rounded;
  static const emptyImageBroken = Icons.broken_image_outlined;
}
