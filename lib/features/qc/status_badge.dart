import 'package:flutter/material.dart';

/// Badge status QC dengan warna per status (Fase A2.5):
/// menunggu_hasil = oranye, lolos = hijau, tidak_lolos = merah.
class QcStatusBadge extends StatelessWidget {
  const QcStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'lolos' => (Colors.green.shade100, Colors.green.shade900),
      'tidak_lolos' => (Colors.red.shade100, Colors.red.shade900),
      'menunggu_hasil' => (Colors.orange.shade100, Colors.orange.shade900),
      _ => (Colors.grey.shade200, Colors.grey.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        qcStatusLabel(status),
        style:
            TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
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
