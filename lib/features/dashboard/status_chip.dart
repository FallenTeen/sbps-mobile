import 'package:flutter/material.dart';

/// Batas server: maksimal 20 item terbaru untuk PO pending /
/// invoice belum dibayar (docs/api-mobile.md §12.7–12.8).
const kPoPendingLimit = 20;

/// Chip status generik dengan warna netral-hijau-kuning-merah.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final l = label.toLowerCase();
    final (bg, fg) = switch (l) {
      'lolos' || 'lunas' || 'aktif' || 'diterima' => (
          Colors.green.shade100,
          Colors.green.shade900
        ),
      'draft' ||
        'diajukan' ||
        'terkirim' ||
        'menunggu_approval_finance' ||
        'menunggu_approval_owner' ||
        'lunas_sebagian' => (
          Colors.orange.shade100,
          Colors.orange.shade900
        ),
      'tidak_lolos' || 'jatuh_tempo' => (Colors.red.shade100, Colors.red.shade900),
      _ => (Colors.grey.shade200, Colors.grey.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _pretty(l),
        style: TextStyle(fontSize: 10.5, color: fg, fontWeight: FontWeight.w600),
      ),
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
