import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../../core/outbox/pending_action.dart';
import '../../core/photo_compression_service.dart';
import 'models/presensi_hari_ini.dart';
import 'presensi_providers.dart';

String presensiSubmissionMessage(CheckInResult result) {
  if (result.luarRadius) {
    return 'Presensi tercatat — Di luar area kerja. Foto dan lokasi tetap tersimpan untuk review.';
  }

  if (result.queued) {
    return 'Tersimpan offline — akan dikirim otomatis saat online.';
  }

  if (result.error != null) {
    return result.error!;
  }

  return 'Presensi berhasil dicatat.';
}

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
      loading: () => SkeletonCard(height: 120),
      error: (error, _) => _ErrorCard(
        message: '$error',
        onRetry: () => ref.invalidate(hariIniProvider),
      ),
      data: (presensi) => switch (presensi.status) {
        PresensiStatus.belumCheckIn => _CheckInCard(
          presensi: presensi,
          busyPhase: busyPhase,
          siap: titik != null,
          onCheckIn: () =>
              _pickAndSubmit(context, ref, PendingEndpoint.presensiCheckIn),
        ),
        PresensiStatus.menungguCheckOut => _WorkingCard(
          presensi: presensi,
          busyPhase: busyPhase,
          onCheckOut: () =>
              _pickAndSubmit(context, ref, PendingEndpoint.presensiCheckOut),
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

    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(presensiSubmitProvider.notifier)
        .submit(endpoint: endpoint, photoPath: photo.path);

    if (result.delivered) {
      HapticFeedback.mediumImpact();
      ref.invalidate(hariIniProvider);
      if (result.luarRadius) {
        AnalyticsService.radiusWarningShown();
      }
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(presensiSubmissionMessage(result)),
            backgroundColor: result.luarRadius
                ? context.colors.warning
                : context.colors.success,
          ),
        );
      }
    } else if (result.queued) {
      HapticFeedback.selectionClick();
      messenger.showSnackBar(
        SnackBar(
          content: Text(presensiSubmissionMessage(result)),
          backgroundColor: context.colors.warning,
        ),
      );
    } else if (result.error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(presensiSubmissionMessage(result)),
          backgroundColor: context.colors.error,
        ),
      );
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
              ? AppTheme.primaryGradient.colors
              : [Colors.grey.shade400, Colors.grey.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (siap ? context.colors.primary : Colors.grey).withValues(
              alpha: 0.25,
            ),
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
                  child: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 24,
                  ),
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
                        siap
                            ? 'Siap untuk check-in'
                            : 'Pilih titik kerja terlebih dahulu',
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
            SizedBox(height: 16),
            BouncingButton(
              onPressed: (!siap || busy) ? null : onCheckIn,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (!siap || busy) ? null : onCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: siap
                        ? context.colors.primary
                        : Colors.grey,
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
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.08),
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
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.colors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.work_rounded,
                    color: context.colors.success,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sedang Bekerja',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        presensi.titik?.nama ?? 'Titik Anda',
                        style: TextStyle(
                          color: context.colors.primary,
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
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: context.colors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Check-in pukul ${fmtWaktu(presensi.checkIn)}',
                    style: TextStyle(
                      color: context.colors.textSecondary,
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
                  side: BorderSide(color: context.colors.error),
                  foregroundColor: context.colors.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.error,
                        ),
                      )
                    : Icon(Icons.logout_rounded),
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
}

// ── Completed Card ────────────────────────────────────────────────────────────

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.presensi});

  final PresensiHariIni presensi;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.colors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: context.colors.success,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Presensi Selesai',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Masuk ${fmtWaktu(presensi.checkIn)} — Pulang ${fmtWaktu(presensi.checkOut)}',
                    style: TextStyle(
                      color: context.colors.textTertiary,
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
}

// ── Error Card ────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: context.colors.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Gagal memuat status presensi',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(color: context.colors.textTertiary, fontSize: 12),
          ),
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
