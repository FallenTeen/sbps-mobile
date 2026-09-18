import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/formatters.dart';
import '../../core/outbox/pending_action.dart';
import '../../core/photo_compression_service.dart';
import '../../core/watermark_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'models/presensi_hari_ini.dart';
import 'models/titik.dart';
import 'presensi_providers.dart';

String presensiSubmissionMessage(CheckInResult result) {
  if (result.luarRadius) {
    return 'Presensi tercatat — Di luar area kerja. Foto dan lokasi tetap tersimpan untuk review.';
  }

  if (result.queued) {
    return kCopyQueued;
  }

  if (result.error != null) {
    return result.error!;
  }

  return 'Presensi berhasil dicatat.';
}

String _fmtDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${fmtNum(meters / 1000)} km';
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
    final pending = ref.watch(pendingPresensiProvider);
    final lokasi = ref.watch(locationProvider);
    final jarakTitik = ref.watch(selectedTitikDistanceProvider);

    return hariIniAsync.when(
      loading: () => SkeletonCard(height: 120),
      error: (error, _) => _ErrorCard(
        message: friendlyErrorMessage(error),
        onRetry: () => ref.invalidate(hariIniProvider),
      ),
      data: (presensi) => switch (presensi.status) {
        PresensiStatus.belumCheckIn => _CheckInCard(
          presensi: presensi,
          busyPhase: busyPhase,
          lokasi: lokasi,
          titik: titik,
          jarakTitik: jarakTitik,
          menungguSinkron: pending.checkInPending,
          onCheckIn: () =>
              _pickAndSubmit(context, ref, PendingEndpoint.presensiCheckIn),
          onRefreshLokasi: () => ref.read(locationProvider.notifier).refresh(),
        ),
        PresensiStatus.menungguCheckOut => _WorkingCard(
          presensi: presensi,
          busyPhase: busyPhase,
          lokasi: lokasi,
          jarakTitik: jarakTitik,
          menungguSinkron: pending.checkOutPending,
          onCheckOut: () =>
              _pickAndSubmit(context, ref, PendingEndpoint.presensiCheckOut),
          onRefreshLokasi: () => ref.read(locationProvider.notifier).refresh(),
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

    // Tolak aksi ganda: bila aksi yang sama sudah mengantre di outbox
    // (pernah gagal terkirim / offline), jangan membuat duplikat.
    final pending = ref.read(pendingPresensiProvider);
    final duplikat = endpoint == PendingEndpoint.presensiCheckIn
        ? pending.checkInPending
        : pending.checkOutPending;
    if (duplikat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presensi masih menunggu sinkron. coba lagi nanti.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Gate: titik terpilih + GPS siap (posisi ada, tidak basi, tidak loading).
    final titik = ref.read(selectedTitikProvider);
    final lokasi = ref.read(locationProvider);
    if (titik == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih titik kerja terlebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!lokasi.ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lokasi.hasPosition && lokasi.isStale
                ? 'Posisi GPS sudah lama. Segarkan lokasi sebelum check-in.'
                : 'Posisi GPS belum siap. Pastikan lokasi aktif lalu coba lagi.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Pre-feedback: bila posisi di luar radius titik saat check-in, jelaskan
    // jarak, batas radius, dan konsekuensinya SEBELUM aksi. Backend tetap
    // validator final — business rule radius tidak diubah.
    if (endpoint == PendingEndpoint.presensiCheckIn) {
      final jarak = ref.read(selectedTitikDistanceProvider);
      if (jarak != null && jarak > titik.radiusPresensiMeter) {
        final lanjut = await _showLuarRadiusSheet(
          context,
          titik: titik,
          jarak: jarak,
        );
        if (!lanjut || !context.mounted) return;
      }
    }

    // Kamera → pratinjau → ambil ulang / lanjut.
    final photo = await _captureWithPreview(context, ref);
    if (photo == null || !context.mounted) return;

    final result = await ref
        .read(presensiSubmitProvider.notifier)
        .submit(endpoint: endpoint, photoPath: photo.path);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (result.delivered) {
      HapticFeedback.mediumImpact();
      ref.invalidate(hariIniProvider);
      if (result.luarRadius) {
        AnalyticsService.radiusWarningShown();
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(presensiSubmissionMessage(result)),
          backgroundColor: result.luarRadius
              ? context.colors.warning
              : context.colors.success,
        ),
      );
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

  /// Ambil foto kamera lalu tampilkan pratinjau; user bisa ambil ulang,
  /// membatalkan, atau mengirim. Kembalikan foto bila user memilih kirim.
  Future<CapturedPhoto?> _captureWithPreview(
    BuildContext context,
    WidgetRef ref,
  ) async {
    while (context.mounted) {
      final photo = await takeWatermarkedPhoto(ref);
      if (photo == null || !context.mounted) return null;

      final choice = await _showPreviewSheet(context, photo);
      if (!context.mounted) return null;
      switch (choice) {
        case _PreviewChoice.kirim:
          return photo;
        case _PreviewChoice.ambilUlang:
          continue;
        case _PreviewChoice.batal:
        case null:
          return null;
      }
    }
    return null;
  }

  Future<_PreviewChoice?> _showPreviewSheet(
    BuildContext context,
    CapturedPhoto photo,
  ) {
    return showModalBottomSheet<_PreviewChoice>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final adaLokasi = photo.gpsStatus == GpsStatus.available &&
            photo.latitude != null &&
            photo.longitude != null;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pratinjau Foto Presensi',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(photo.path)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      adaLokasi
                          ? Icons.location_on
                          : Icons.location_off_outlined,
                      size: 16,
                      color: adaLokasi
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        adaLokasi
                            ? 'Foto dilengkapi data lokasi (watermark).'
                            : 'Foto tanpa data lokasi — koordinat GPS atmosferik dipakai.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // OverflowBar: deretan tombol turun ke baris baru saat
                // sempit / text scale 130%, bukan memicu overflow.
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(_PreviewChoice.batal),
                      child: const Text('Batal'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(_PreviewChoice.ambilUlang),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Ambil Ulang'),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(sheetContext).pop(_PreviewChoice.kirim),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Kirim'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Jelaskan posisi di luar radius sebelum check-in: jarak saat ini, batas
  /// radius, dan langkah yang bisa diambil user. Mengembalikan true bila
  /// user tetap ingin melanjutkan.
  Future<bool> _showLuarRadiusSheet(
    BuildContext context, {
    required Titik titik,
    required double jarak,
  }) async {
    final hasil = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Di luar radius ${titik.nama}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Posisi Anda saat ini berjarak ${_fmtDistance(jarak)} dari titik "${titik.nama}" — melebihi radius presensi ${titik.radiusPresensiMeter.round()} m yang ditetapkan.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Anda tetap bisa melanjutkan; presensi akan ditandai "di luar area kerja" untuk ditinjau atasan. Untuk presensi normal, mendekatlah ke titik kerja dalam radius ${titik.radiusPresensiMeter.round()} m lalu coba lagi.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(false),
                        child: const Text('Tutup'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Lanjutkan Presensi'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return hasil ?? false;
  }
}

/// Kebutuhan pratinjau foto presensi.
enum _PreviewChoice { kirim, ambilUlang, batal }

// ── Check-In Card ─────────────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.presensi,
    required this.busyPhase,
    required this.lokasi,
    required this.titik,
    required this.jarakTitik,
    required this.menungguSinkron,
    required this.onCheckIn,
    required this.onRefreshLokasi,
  });

  final PresensiHariIni presensi;
  final UploadPhase? busyPhase;
  final LocationSnapshot lokasi;
  final Titik? titik;
  final double? jarakTitik;
  final bool menungguSinkron;
  final VoidCallback onCheckIn;
  final VoidCallback onRefreshLokasi;

  @override
  Widget build(BuildContext context) {
    final busy = busyPhase != null;
    final siap = titik != null && lokasi.ready;
    final aktif = siap && !busy && !menungguSinkron;

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
                        menungguSinkron
                            ? 'Check-in menunggu sinkron'
                            : (siap
                                  ? 'Siap untuk check-in'
                                  : 'Pilih titik kerja & pastikan lokasi siap'),
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
            const SizedBox(height: 14),
            _GpsStatusStrip(
              lokasi: lokasi,
              titik: titik,
              jarakTitik: jarakTitik,
              onRefresh: onRefreshLokasi,
              busy: busy || menungguSinkron,
              onGradient: true,
            ),
            const SizedBox(height: 14),
            BouncingButton(
              onPressed: aktif ? onCheckIn : null,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: aktif ? onCheckIn : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: (siap && !menungguSinkron)
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
                    _ => menungguSinkron ? 'Menunggu Sinkron...' : 'Check-In Sekarang',
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
    required this.lokasi,
    required this.jarakTitik,
    required this.menungguSinkron,
    required this.onCheckOut,
    required this.onRefreshLokasi,
  });

  final PresensiHariIni presensi;
  final UploadPhase? busyPhase;
  final LocationSnapshot lokasi;
  final double? jarakTitik;
  final bool menungguSinkron;
  final VoidCallback onCheckOut;
  final VoidCallback onRefreshLokasi;

  @override
  Widget build(BuildContext context) {
    final busy = busyPhase != null;
    final aktif = lokasi.ready && !busy && !menungguSinkron;

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
            const SizedBox(height: 12),
            _GpsStatusStrip(
              lokasi: lokasi,
              titik: presensi.titik,
              jarakTitik: jarakTitik,
              onRefresh: onRefreshLokasi,
              busy: busy || menungguSinkron,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: aktif ? onCheckOut : null,
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
                  _ => menungguSinkron ? 'Menunggu Sinkron...' : 'Check-Out',
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bilah status GPS pada kartu presensi: kondisi lokasi + jarak ke titik
/// terpilih serta status dalam/luar radius. Tombol segarkan tersedia bila
/// posisi sedang bermasalah / basi.
class _GpsStatusStrip extends StatelessWidget {
  const _GpsStatusStrip({
    required this.lokasi,
    required this.titik,
    required this.jarakTitik,
    required this.onRefresh,
    required this.busy,
    this.onGradient = false,
  });

  final LocationSnapshot lokasi;
  final Titik? titik;
  final double? jarakTitik;
  final VoidCallback onRefresh;
  final bool busy;
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    final t = titik; // lokal agar dapat di-promote oleh branch null-check
    final jd = jarakTitik;

    final Color bg; // warna latar strip
    final Color fg; // warna teks/ikon
    final IconData icon;
    final String pesan;
    final bool showRefresh;

    if (lokasi.problem != null) {
      bg = Colors.black.withValues(alpha: 0.25);
      fg = Colors.white;
      icon = Icons.location_off_outlined;
      pesan = lokasi.problemLabel!;
      showRefresh = true;
    } else if (lokasi.loading && !lokasi.hasPosition) {
      bg = Colors.black.withValues(alpha: 0.25);
      fg = Colors.white;
      icon = Icons.gps_fixed;
      pesan = 'Mengambil lokasi Anda…';
      showRefresh = false;
    } else if (lokasi.hasPosition && lokasi.isStale) {
      bg = onGradient
          ? AppTheme.primaryGradient.colors.first.withValues(alpha: 0.9)
          : context.colors.warning.withValues(alpha: 0.12);
      fg = onGradient ? Colors.white : context.colors.warning;
      icon = Icons.schedule;
      pesan = 'Posisi GPS sudah lama. Segarkan sebelum presensi.';
      showRefresh = true;
    } else if (t == null) {
      bg = Colors.black.withValues(alpha: 0.25);
      fg = Colors.white;
      icon = Icons.place_outlined;
      pesan = 'Pilih titik kerja di bawah untuk check-in.';
      showRefresh = false;
    } else if (jd != null && jd > t.radiusPresensiMeter) {
      bg = onGradient
          ? Colors.amber.shade600.withValues(alpha: 0.95)
          : context.colors.warning.withValues(alpha: 0.14);
      fg = onGradient ? Colors.white : context.colors.warning;
      icon = Icons.warning_amber_rounded;
      pesan =
          'Luar radius — ${_fmtDistance(jd)} dari "${t.nama}" (batas ${t.radiusPresensiMeter.round()} m). Presensi akan ditandai untuk review.';
      showRefresh = false;
    } else if (jd != null) {
      bg = onGradient
          ? Colors.white.withValues(alpha: 0.2)
          : context.colors.success.withValues(alpha: 0.1);
      fg = onGradient ? Colors.white : context.colors.success;
      icon = Icons.check_circle_outline;
      pesan =
          'Dalam radius — ${_fmtDistance(jd)} dari "${t.nama}".';
      showRefresh = false;
    } else {
      bg = Colors.black.withValues(alpha: 0.25);
      fg = Colors.white;
      icon = Icons.my_location;
      pesan = 'Lokasi siap.';
      showRefresh = false;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan,
              style: TextStyle(color: fg, fontSize: 12.5, height: 1.3),
            ),
          ),
          if (showRefresh && !busy)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Segarkan lokasi',
              icon: Icon(Icons.refresh, size: 20, color: fg),
              onPressed: onRefresh,
            ),
        ],
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