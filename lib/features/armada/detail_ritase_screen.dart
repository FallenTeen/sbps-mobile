import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/utils/status_labels.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_screen_frame.dart';
import '../../shared/widgets/illustrated_empty_state.dart';
import '../../shared/widgets/key_value_row.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/ritase_status_badges.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/sticky_action_bar.dart';
import '../../shared/widgets/timeline.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

bool _tanggalLocaleReady = false;

void _ensureTanggalLocale() {
  if (_tanggalLocaleReady) return;
  initializeDateFormatting('id_ID');
  _tanggalLocaleReady = true;
}

String _fmtDetailTanggal(dynamic input) {
  _ensureTanggalLocale();
  return fmtTanggal(input);
}

String _fmtDetailWaktu(dynamic input) {
  _ensureTanggalLocale();
  return fmtTanggalWaktu(input);
}

/// Detail satu ritase: ringkasan muatan, status verifikasi, dan alur ritase.
class DetailRitaseScreen extends ConsumerStatefulWidget {
  const DetailRitaseScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<DetailRitaseScreen> createState() => _DetailRitaseScreenState();
}

class _DetailRitaseScreenState extends ConsumerState<DetailRitaseScreen> {
  bool _submitting = false;

  Future<void> _selesaikan() async {
    if (_submitting || !mounted) return;
    setState(() => _submitting = true);
    try {
      await ref.read(armadaRepositoryProvider).selesaikanRitase(widget.id);
      if (!mounted) return;
      ref.invalidate(detailRitaseProvider(widget.id));
      ref.invalidate(ritaseHariIniProvider);
      ref.invalidate(ritaseRiwayatProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ritase berhasil ditandai selesai')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              error,
              fallback: 'Gagal menandai ritase selesai. Coba lagi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(detailRitaseProvider(widget.id));

    return Scaffold(
      body: AppScreenFrame(
        title: 'Detail Muatan',
        subtitle: 'Armada / Detail Muatan',
        actions: const [PortalSwitchButton()],
        maxWidth: AppBreakpoints.maxContentWidth - (AppSpacing.md * 2),
        body: detail.when(
          loading: () => const SkeletonDetailView(),
          error: (error, _) => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal memuat data',
            subtitle: friendlyErrorMessage(error),
            illustrationVariant: EmptyStateVariant.error,
            actionLabel: 'Coba lagi',
            onAction: () => ref.invalidate(detailRitaseProvider(widget.id)),
          ),
          data: (ritase) => RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(detailRitaseProvider(widget.id)),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _SummaryCard(ritase: ritase),
                const SectionHeader(title: 'Alur Ritase'),
                if (ritase.timeline.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Belum ada alur ritase.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Timeline(items: _timelineItems(ritase)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: detail.maybeWhen<Widget?>(
        data: (ritase) => ritase.bisaSelesaikan
            ? StickyActionBar(
                primaryLabel: 'Selesaikan Ritase',
                primaryIcon: Icons.check_circle_outline,
                showPrimaryLoading: _submitting,
                onPrimary: _selesaikan,
              )
            : null,
        orElse: () => null,
      ),
    );
  }
}

TimelineStatus timelineStatusFor(String state) => switch (state) {
  'done' => TimelineStatus.done,
  'current' => TimelineStatus.current,
  'pending' => TimelineStatus.pending,
  _ => TimelineStatus.pending,
};

List<TimelineItem> _timelineItems(RitaseItem ritase) => [
  for (final entry in ritase.timeline)
    TimelineItem(
      title: entry.label,
      subtitle: _timelineSubtitle(entry),
      status: timelineStatusFor(entry.state),
    ),
];

String? _timelineSubtitle(RitaseTimelineEntry entry) {
  final head = <String>[
    if (entry.badge.isNotEmpty) entry.badge,
    if (entry.actor != null && entry.actor!.trim().isNotEmpty) entry.actor!,
    if (entry.at != null && entry.at!.trim().isNotEmpty)
      _fmtDetailWaktu(entry.at),
  ].join(' • ');

  final lines = <String>[
    if (head.isNotEmpty) head,
    for (final detail in entry.details)
      '${detail.label}: ${detail.value ?? '-'}',
  ];
  return lines.isEmpty ? null : lines.join('\n');
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.ritase});

  final RitaseItem ritase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final rute = ritase.ruteAsal != null && ritase.ruteTujuan != null
        ? '${ritase.ruteAsal} → ${ritase.ruteTujuan}'
        : null;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ritase.armadaPlat ?? 'Armada #${ritase.armadaId ?? '-'}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _fmtDetailTanggal(ritase.tanggal),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ritaseStatusBadges(
                statusLabel: ritase.status == null
                    ? 'Ritase'
                    : statusLabel(ritase.status!),
                terverifikasi:
                    ritase.isVerifiedLogistik || ritase.isVerifiedSecurity,
                selesai: ritase.isSelesai,
              ),
            ),
            if (ritase.material != null) ...[
              const SizedBox(height: 12),
              KeyValueRow(label: 'Material', value: ritase.material!),
            ],
            if (rute != null) ...[
              const SizedBox(height: 4),
              KeyValueRow(label: 'Rute', value: rute),
            ],
            if (ritase.proyek != null) ...[
              const SizedBox(height: 4),
              KeyValueRow(label: 'Proyek', value: ritase.proyek!),
            ],
            if (ritase.titik != null) ...[
              const SizedBox(height: 4),
              KeyValueRow(label: 'Titik', value: ritase.titik!),
            ],
            const SizedBox(height: 12),
            Text(
              'Jumlah: ${fmtNum(ritase.jumlahRit)} '
              '${ritase.satuanMuatan ?? 'rit'}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (ritase.totalUpahRit != null) ...[
              const SizedBox(height: 4),
              Text(
                'Upah: ${fmtRp(ritase.totalUpahRit!)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
            if (ritase.hasSelisih ||
                (ritase.wajibJembatanTimbang == true &&
                    !ritase.isVerifiedLogistik)) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (ritase.hasSelisih)
                    StatusPill(
                      label: 'Selisih',
                      color: colors.error,
                      icon: Icons.warning_amber_rounded,
                      borderRadius: 999,
                    ),
                  if (ritase.wajibJembatanTimbang == true &&
                      !ritase.isVerifiedLogistik)
                    StatusPill(
                      label: 'Wajib Timbang',
                      color: colors.secondary,
                      icon: Icons.scale_rounded,
                      borderRadius: 999,
                    ),
                ],
              ),
            ],
            if (ritase.catatan != null &&
                ritase.catatan!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              KeyValueRow(label: 'Catatan', value: ritase.catatan!),
            ],
          ],
        ),
      ),
    );
  }
}
