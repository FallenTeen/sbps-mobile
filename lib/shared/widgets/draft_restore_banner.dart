import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Banner ringan yang ditampilkan di atas form saat draft ditemukan
/// (Rencana §1.3 — trigger pemulihan).
///
/// Menawarkan dua opsi:
/// - "Lanjutkan Draft" → mengisi form dari draft yang tersimpan.
/// - "Mulai Baru" → menghapus draft dan memulai dari awal.
///
/// Tidak blok modal — cukup ringan di atas form, tidak mengganggu flow.
class DraftRestoreBanner extends StatelessWidget {
  const DraftRestoreBanner({
    super.key,
    required this.savedAt,
    required this.onContinue,
    required this.onDiscard,
    this.warning,
  });

  /// Timestamp terakhir draft disimpan.
  final DateTime savedAt;

  /// Dipanggil saat user memilih "Lanjutkan Draft".
  final VoidCallback onContinue;

  /// Dipanggil saat user memilih "Mulai Baru" (draft dihapus).
  final VoidCallback onDiscard;

  /// Pesan peringatan opsional (mis. "Data GPS/foto mungkin sudah tidak
  /// sesuai kondisi terkini").
  final String? warning;

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return DateFormat('d MMM y, HH:mm', 'id_ID').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: cs.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Draft ditemukan, terakhir diisi ${_relativeTime(savedAt)}.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (warning != null) ...[
              const SizedBox(height: 4),
              Text(
                warning!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onTertiaryContainer.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: onContinue,
                  child: const Text('Lanjutkan Draft'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onDiscard,
                  child: const Text('Mulai Baru'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
