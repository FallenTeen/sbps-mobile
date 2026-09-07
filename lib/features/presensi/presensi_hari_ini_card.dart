import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/outbox/pending_action.dart';
import '../../core/photo_compression_service.dart';
import 'models/presensi_hari_ini.dart';
import 'presensi_providers.dart';

/// Kartu alur presensi harian (Fase A1.4): Check-in / Check-out / ringkasan
/// selesai — mengikuti state dari GET /presensi/hari-ini.
class PresensiHariIniCard extends ConsumerWidget {
  const PresensiHariIniCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hariIniAsync = ref.watch(hariIniProvider);
    final submitState = ref.watch(presensiSubmitProvider);
    final busyPhase = submitState.busy ? submitState.phase : null;
    final titik = ref.watch(selectedTitikProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hariIniAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Gagal memuat status presensi.', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('$error', style: theme.textTheme.bodySmall),
              TextButton.icon(
                onPressed: () => ref.invalidate(hariIniProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
          data: (presensi) => switch (presensi.status) {
            PresensiStatus.belumCheckIn => _belumCheckIn(
                context, ref, theme, presensi, busyPhase, titik != null),
            PresensiStatus.menungguCheckOut => _menungguCheckOut(
                context, ref, theme, presensi, busyPhase),
            PresensiStatus.selesai => _selesai(theme, presensi),
          },
        ),
      ),
    );
  }

  Widget _belumCheckIn(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    PresensiHariIni presensi,
    UploadPhase? busyPhase,
    bool siap,
  ) {
    final busy = busyPhase != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Presensi Hari Ini', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          siap
              ? 'Foto wajah akan diambil sebagai bukti kehadiran.'
              : 'Pilih titik kerja dan tunggu lokasi siap untuk check-in.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: (!siap || busy)
              ? null
              : () => _pickAndSubmit(
                  context, ref, PendingEndpoint.presensiCheckIn),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.login),
          label: Text(switch (busyPhase) {
            UploadPhase.compressing => 'Mengompres foto...',
            UploadPhase.sending => 'Mengirim...',
            _ => 'Check-In',
          }),
        ),
      ],
    );
  }

  Widget _menungguCheckOut(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    PresensiHariIni presensi,
    UploadPhase? busyPhase,
  ) {
    final busy = busyPhase != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Sedang bekerja di ${presensi.titik?.nama ?? 'titik Anda'}',
                  style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Check-in pukul ${_fmtJam(presensi.checkIn)}',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed:
              busy ? null : () => _pickAndSubmit(context, ref, PendingEndpoint.presensiCheckOut),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.logout),
          label: Text(switch (busyPhase) {
            UploadPhase.compressing => 'Mengompres foto...',
            UploadPhase.sending => 'Mengirim...',
            _ => 'Check-Out',
          }),
        ),
      ],
    );
  }

  Widget _selesai(ThemeData theme, PresensiHariIni presensi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('Presensi hari ini selesai', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Masuk ${_fmtJam(presensi.checkIn)} — Pulang ${_fmtJam(presensi.checkOut)}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  // -- Alur foto + submit ----------------------------------------------------

  Future<void> _pickAndSubmit(
    BuildContext context,
    WidgetRef ref,
    PendingEndpoint endpoint,
  ) async {
    if (!context.mounted) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final result = await ref
        .read(presensiSubmitProvider.notifier)
        .submit(endpoint: endpoint, photoPath: picked.path);

    if (result.delivered) {
      if (result.luarRadius && context.mounted) {
        // Warning non-blocking — backend tetap menerima.
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Di luar radius titik'),
            content: const Text(
              'Lokasi Anda berada di luar radius titik kerja. Presensi tetap '
              'tercatat dan akan ditinjau oleh admin.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Presensi berhasil dicatat.')),
        );
      }
    } else if (result.queued) {
      messenger.showSnackBar(const SnackBar(
        content:
            Text('Tersimpan. Menunggu sinkronisasi otomatis saat online.'),
      ));
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.error!),
        backgroundColor: errorColor,
      ));
    }
  }

  String _fmtJam(String? iso) {
    if (iso == null) return '-';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
