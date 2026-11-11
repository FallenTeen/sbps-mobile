import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';

/// Badge status QC dengan warna per status (Fase A2.5):
/// menunggu_hasil = oranye, lolos = hijau, tidak_lolos = merah.
class QcStatusBadge extends StatelessWidget {
  const QcStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'lolos' => (
        context.colors.success.withValues(alpha: 0.15),
        context.colors.success,
      ),
      'tidak_lolos' => (
        context.colors.error.withValues(alpha: 0.15),
        context.colors.error,
      ),
      'menunggu_hasil' => (
        context.colors.warning.withValues(alpha: 0.15),
        context.colors.warning,
      ),
      _ => (context.colors.surfaceVariant, context.colors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        qcStatusLabel(status),
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String qcStatusLabel(String status) => switch (status) {
  'menunggu_hasil' => 'Menunggu hasil',
  'lolos' => 'Lolos',
  'tidak_lolos' => 'Tidak lolos',
  _ => status,
};
