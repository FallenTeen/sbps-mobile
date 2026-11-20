import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/utils/status_labels.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/illustrated_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/timeline.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

/// Detail satu ritase: ringkasan muatan, status verifikasi, dan alur ritase.
class DetailRitaseScreen extends ConsumerWidget {
  const DetailRitaseScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(detailRitaseProvider(id));

    return Scaffold(
      appBar: AppBar(
        title: const BreadcrumbTitle(
          parentLabel: 'Armada',
          title: 'Detail Muatan',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: detail.when(
        loading: () => const SkeletonDetailView(),
        error: (error, _) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat data',
          subtitle: friendlyErrorMessage(error),
          illustrationVariant: EmptyStateVariant.error,
          actionLabel: 'Coba lagi',
          onAction: () => ref.invalidate(detailRitaseProvider(id)),
        ),
        data: (ritase) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(detailRitaseProvider(id)),
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
      fmtTanggalWaktu(entry.at),
  ].join(' • ');

  final lines = <String>[
    if (head.isNotEmpty) head,
    for (final detail in entry.details)
      '${detail.label}: ${detail.value ?? '-'}',
  ];
  return lines.isEmpty ? null : lines.join('\n');
}

String _labelStatus(String status) => switch (status) {
  'draft' => 'Draft',
  'disetujui' => 'Disetujui',
  'ditagih' => 'Ditagih',
  _ => status.isEmpty ? status : status[0].toUpperCase() + status.substring(1),
};

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
              fmtTanggal(ritase.tanggal),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (ritase.status != null || ritase.isSelesai) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (ritase.status != null)
                    StatusPill(
                      label: _labelStatus(ritase.status!),
                      color: statusColor(ritase.status!, context),
                      borderRadius: 999,
                    ),
                  if (ritase.isSelesai)
                    StatusPill(
                      label: 'Selesai',
                      color: colors.success,
                      icon: Icons.check_circle_outline,
                    ),
                ],
              ),
            ],
            if (ritase.material != null) ...[
              const SizedBox(height: 12),
              _infoRow(context, 'Material', ritase.material!),
            ],
            if (rute != null) ...[
              const SizedBox(height: 4),
              _infoRow(context, 'Rute', rute),
            ],
            if (ritase.proyek != null) ...[
              const SizedBox(height: 4),
              _infoRow(context, 'Proyek', ritase.proyek!),
            ],
            if (ritase.titik != null) ...[
              const SizedBox(height: 4),
              _infoRow(context, 'Titik', ritase.titik!),
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
            if (ritase.hasVerifikasiData) ...[
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
                  if (ritase.isVerifiedSecurity)
                    StatusPill(
                      label: 'Verified (Security)',
                      color: colors.success,
                      icon: Icons.shield_outlined,
                      borderRadius: 999,
                    ),
                  if (ritase.isVerifiedLogistik)
                    StatusPill(
                      label: 'Verified (Logistik)',
                      color: colors.info,
                      icon: Icons.verified_outlined,
                      borderRadius: 999,
                    )
                  else if (ritase.isMenungguVerifikasi)
                    StatusPill(
                      label: 'Menunggu verifikasi',
                      color: colors.warning,
                      icon: Icons.hourglass_top_rounded,
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
            if (ritase.catatan != null && ritase.catatan!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoRow(context, 'Catatan', ritase.catatan!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) => RichText(
    text: TextSpan(
      style: Theme.of(context).textTheme.bodyMedium,
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        TextSpan(text: value),
      ],
    ),
  );
}
