import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/status_labels.dart';
import 'status_pill.dart';

List<Widget> ritaseStatusBadges({
  required String statusLabel,
  required bool terverifikasi,
  required bool selesai,
}) {
  Widget badge({
    required String label,
    required Color Function(AppColors colors, BuildContext context)
    resolveColor,
    IconData? icon,
  }) {
    return Builder(
      builder: (context) {
        final colors = context.colors;
        return StatusPill(
          label: label,
          color: resolveColor(colors, context),
          icon: icon,
          borderRadius: 999,
        );
      },
    );
  }

  final statusKey = statusLabel.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    '_',
  );

  return [
    badge(
      label: statusLabel,
      resolveColor: (colors, context) => statusColor(statusKey, context),
    ),
    if (terverifikasi)
      badge(
        label: 'Terverifikasi',
        resolveColor: (colors, context) => colors.success,
        icon: Icons.verified_outlined,
      ),
    if (selesai)
      badge(
        label: 'Selesai',
        resolveColor: (colors, context) => colors.success,
        icon: Icons.check_circle_outline,
      ),
  ];
}
