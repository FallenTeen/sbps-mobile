import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../../core/outbox/pending_action.dart';
import '../../core/photo_compression_service.dart';
import 'models/presensi_hari_ini.dart';
import 'presensi_providers.dart';

/// Kartu alur presensi harian: Check-in / Check-out / ringkasan selesai.
class PresensiHariIniCard extends ConsumerWidget {
  const PresensiHariIniCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hariIniAsync = ref.watch(hariIniProvider);
    final submitState = ref.watch(presensiSubmitProvider);
    final busyPhase = submitState.busy ? submitState.phase : null;
    final titik = ref.watch(selectedTitikProvider);

    return hariIniAsync.when(
      loading: () => const SkeletonCard(height: 120),
      error: (error, _) => _ErrorCard(
        message: '$error',
        onRetry: () => ref.invalidate(hariIniProvider),
      ),
      data: (presensi) => switch (presensi.status) {
        PresensiStatus.belumCheckIn => _CheckInCard(
            presensi: presensi,
            busyPhase: busyPhase,
            siap: titik != null,
            onCheckIn: () => _pickAndSubmit(
                context, ref, PendingEndpoint.presensiCheckIn),
          ),
        PresensiStatus.menungguCheckOut => _WorkingCard(
            presensi: presensi,
            busyPhase: busyPhase,
            onCheckOut: () => _pickAndSubmit(
                context, ref, PendingEndpoint.presensiCheckOut),
          ),
        PresensiStatus.selesai => _CompletedCard(presensi: presensi),
      },
    );
  }

  Future<void> _pickAndSubmit(
    BuildContext context,
    WidgetRef ref,
    PendingEndpoint endpoint,
  ) async {
    if (!context.mounted) return;

    final photo = await ref.takeWatermarkedPhoto();
    if (photo == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(presensiSubmitProvider.notifier)
        .submit(endpoint: endpoint, photoPath: photo.path);

    if (result.delivered) {
      if (result.luarRadius && context.mounted) {
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
        content: Text('Tersimpan. Menunggu sinkronisasi otomatis saat online.'),
      ));
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.error!),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }
}

// ── Check-In Card ─────────────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.presensi,
    required this.busyPhase,
    required this.siap,
    required this.onCheckIn,
  });

  final PresensiHariIni presensi;
  final UploadPhase? busyPhase;
  final bool siap;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final busy = busyPhase != null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: siap
              ? [const Color(0xFF0D9488), const Color(0xFF14B8A6)]
              : [Colors.grey.shade400, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (siap ? AppTheme.primaryColor : Colors.grey)
                .withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fingerprint, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Presensi Hari Ini',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        siap ? 'Siap untuk check-in' : 'Pilih titik kerja terlebih dahulu',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BouncingButton(
              onPressed: (!siap || busy) ? null : onCheckIn,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!siap || busy) ? null : onCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: siap ? AppTheme.primaryColor : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(switch (busyPhase) {
                    UploadPhase.compressing => 'Mengompres foto...',
                    UploadPhase.sending => 'Mengirim...',
                    _ => 'Check-In Sekarang',
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Working Card (Sedang Bekerja) ─────────────────────────────────────────────

class _WorkingCard extends StatelessWidget {
  const _WorkingCard({
    required this.presensi,
    required this.busyPhase,
    required this.onCheckOut,
  });

  final PresensiHariIni presensi;
  final UploadPhase? busyPhase;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    final busy = busyPhase != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.work_rounded,
                      color: AppTheme.successColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sedang Bekerja',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        presensi.titik?.nama ?? 'Titik Anda',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariantColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 16, color: AppTheme.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    'Check-in pukul ${_fmtJam(presensi.checkIn)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onCheckOut,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.errorColor),
                  foregroundColor: AppTheme.errorColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.errorColor),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(switch (busyPhase) {
                  UploadPhase.compressing => 'Mengompres foto...',
                  UploadPhase.sending => 'Mengirim...',
                  _ => 'Check-Out',
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtJam(String? iso) {
    if (iso == null) return '-';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ── Completed Card ────────────────────────────────────────────────────────────

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.presensi});

  final PresensiHariIni presensi;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Presensi Selesai',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Masuk ${_fmtJam(presensi.checkIn)} — Pulang ${_fmtJam(presensi.checkOut)}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtJam(String? iso) {
    if (iso == null) return '-';
    final t = DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

// ── Error Card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Gagal memuat status presensi',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}
