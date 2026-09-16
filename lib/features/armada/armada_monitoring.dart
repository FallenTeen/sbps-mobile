/// Logika murni pemantauan armada (Phase 10 — Armada Monitoring).
///
/// Semua peringatan diturunkan dari data yang benar-benar diambil dari API
/// (`/master/armada`, `/armada/checklist-hari-ini`, `/servis-armada`);
/// tidak ada field/angka yang dikarang.
library;

import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import 'models/servis_armada.dart';

/// Satu peringatan untuk sebuah unit armada pada layar monitoring.
class MonitorUnitWarning {
  const MonitorUnitWarning({
    required this.key,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
  });

  /// Kunci identifikasi (mis. `status`, `checklist`, `servis`) — dipakai
  /// untuk mendeduplikasi peringatan & keperluan uji.
  final String key;

  final String message;
  final IconData icon;
}

bool _isOperational(String? status) {
  final s = status?.toLowerCase() ?? '';
  return s.isEmpty || s == 'aktif' || s == 'beroperasi';
}

/// Menyusun daftar peringatan unit dari data nyata.
///
/// - [status]: status unit dari master armada.
/// - [checklistKnown]: apakah unit ada di hasil `/armada/checklist-hari-ini`.
/// - [checklistSudahIsi]: status checklist hari ini unit tsb.
/// - [servis]: daftar servis unit tsb (dari `/servis-armada`).
List<MonitorUnitWarning> unitWarnings({
  required String? status,
  bool checklistKnown = false,
  bool checklistSudahIsi = false,
  List<ServisArmada> servis = const [],
}) {
  final warnings = <MonitorUnitWarning>[];

  if (!_isOperational(status)) {
    warnings.add(
      MonitorUnitWarning(
        key: 'status',
        message: 'Unit berstatus "$status" — tidak beroperasi.',
        icon: Icons.priority_high_rounded,
      ),
    );
  }

  if (checklistKnown && !checklistSudahIsi) {
    warnings.add(
      const MonitorUnitWarning(
        key: 'checklist',
        message: 'Checklist harian hari ini belum diisi.',
        icon: Icons.assignment_late_outlined,
      ),
    );
  }

  final diajukan = servis.where((x) => x.status == 'diajukan').toList();
  final disetujui = servis.where((x) => x.status == 'disetujui').toList();
  final dikerjakan = servis.where((x) => x.status == 'dikerjakan').toList();

  if (diajukan.isNotEmpty) {
    warnings.add(
      MonitorUnitWarning(
        key: 'servis-diajukan',
        message: '${diajukan.length} ajuan servis menunggu persetujuan.',
        icon: Icons.pending_actions_outlined,
      ),
    );
  }
  if (disetujui.isNotEmpty) {
    warnings.add(
      MonitorUnitWarning(
        key: 'servis-disetujui',
        message: '${disetujui.length} servis disetujui — menunggu penjadwalan.',
        icon: Icons.event_available_outlined,
      ),
    );
  }
  if (dikerjakan.isNotEmpty) {
    warnings.add(
      MonitorUnitWarning(
        key: 'servis-dikerjakan',
        message: '${dikerjakan.length} servis sedang dikerjakan workshop.',
        icon: Icons.build_circle_outlined,
      ),
    );
  }

  return warnings;
}

/// Bila unit memiliki indikasi butuh perhatian (ada peringatan).
bool unitNeedsAttention({
  required String? status,
  bool checklistKnown = false,
  bool checklistSudahIsi = false,
  List<ServisArmada> servis = const [],
}) {
  return unitWarnings(
    status: status,
    checklistKnown: checklistKnown,
    checklistSudahIsi: checklistSudahIsi,
    servis: servis,
  ).isNotEmpty;
}

/// Warna status unit: aktif/beroperasi hijau, standby biru, servis orange,
/// rusak/nonaktif merah, lainnya abu-abu. Dipakai bersama di overview &
/// drill-down (rapi & konsisten).
Color armadaStatusColor(BuildContext context, String? status) {
  final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
  return switch (status?.toLowerCase()) {
    'aktif' || 'beroperasi' => colors.success,
    'standby' || 'siaga' => colors.info,
    'servis' || 'perbaikan' || 'maintenance' => colors.warning,
    'rusak' || 'nonaktif' => colors.error,
    _ => colors.textMuted,
  };
}