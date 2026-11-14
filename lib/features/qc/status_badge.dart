import 'package:flutter/material.dart';

import '../../shared/utils/status_labels.dart';
import '../../shared/widgets/status_pill.dart';

/// Label status QC (Fase A2.5).
String qcStatusLabel(String status) => switch (status) {
  'menunggu_hasil' => 'Menunggu hasil',
  'lolos' => 'Lolos',
  'tidak_lolos' => 'Tidak lolos',
  _ => status,
};

/// Badge status QC: wrapper [StatusPill] + `statusColor` supaya konsisten
/// dengan badge status modul lain (menunggu_hasil = warning, lolos = success,
/// tidak_lolos = error).
class QcStatusBadge extends StatelessWidget {
  const QcStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: qcStatusLabel(status),
      color: statusColor(status, context),
      borderRadius: 999,
    );
  }
}
