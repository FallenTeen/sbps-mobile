import 'package:flutter/material.dart';

import '../../shared/utils/status_labels.dart';
import '../../shared/widgets/status_pill.dart';

/// Batas server: maksimal 20 item terbaru untuk PO pending /
/// invoice belum dibayar (docs/api-mobile.md §12.7–12.8).
const kPoPendingLimit = 20;

/// Chip status dashboard: wrapper [StatusPill] + `statusColor` supaya warna
/// status konsisten dengan seluruh modul (tinted pill, label 11/w700).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: _pretty(label.toLowerCase()),
      color: statusColor(label, context),
      borderRadius: 999,
    );
  }

  static String _pretty(String s) {
    const map = {
      'menunggu_approval_finance': 'Menunggu Finance',
      'menunggu_approval_owner': 'Menunggu Owner',
      'lunas_sebagian': 'Lunas sebagian',
      'jatuh_tempo': 'Jatuh tempo',
      'belum_dibayar': 'Belum dibayar',
      'diterima': 'Diterima',
    };
    if (map[s] != null) return map[s]!;
    return s.isEmpty ? '-' : '${s[0].toUpperCase()}${s.substring(1)}';
  }
}
