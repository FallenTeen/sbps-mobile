import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/info_tooltip.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/queue_card.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'models/qc_sample.dart';
import 'qc_providers.dart';
import 'qc_rules.dart';
import 'qc_sheets.dart';
import 'status_badge.dart';

/// Home QC — inspection queue (Phase 14).
///
/// Menampilkan antrian pemeriksaan (sampel `menunggu_hasil`) lengkap dengan
/// context produksi, plus ringkasan "Menunggu Pemeriksaan" (exact dari
/// pagination server) dan "Selesai Hari Ini" (filter tanggal murni).
class QcHomeScreen extends ConsumerWidget {
  const QcHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qcHomeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Control'),
        actions: [
          IconButton(
            tooltip: 'Riwayat QC',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/qc/riwayat'),
          ),
          const PortalSwitchButton(),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: state.when(
          loading: () => const SkeletonListView(itemCount: 4),
          error: (e, _) => errorView(context, ref, e),
          data: (data) => RefreshIndicator(
            onRefresh: () => ref.refresh(qcHomeProvider.future),
            child: _HomeBody(data: data),
          ),
        ),
      ),
    );
  }
}

Widget errorView(BuildContext context, WidgetRef ref, Object e) {
  final message = e is ApiException
      ? e.message
      : 'Gagal memuat antrian QC.';
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Gagal Memuat Antrian QC',
        subtitle: message,
        actionLabel: 'Coba Lagi',
        onAction: () => ref.invalidate(qcHomeProvider),
      ),
    ],
  );
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.data});

  final QcHomeData data;

  void _openInspection(BuildContext context, QcSample? sample) {
    if (sample == null || sample.sessionId == null) return;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UjiTekanSheet(
        sessionId: sample.sessionId!,
        context: QcInspectionContext(
          produkNama: sample.produkNama,
          mesinNama: sample.mesinNama,
          titikNama: sample.titikNama,
          mulai: sample.sesiMulai,
          jenisUji: 'uji_tekan',
          tanggalUjiTekanRencana: sample.tanggalUjiTekanRencana,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = qcHomeSummary(
      menungguPemeriksaan: data.waitingTotal,
      selesaiHariIni: data.selesaiHariIni.length,
    );

    final queue = data.waitingQueue;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _SummaryHeader(summary: summary, date: DateTime.now()),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.rule_folder_outlined, size: 18, color: context.colors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Antrian Pemeriksaan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              queue.isEmpty ? '' : '${queue.length} dari ${summary.menungguPemeriksaan}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (queue.isEmpty)
          AppEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Tidak Ada Pemeriksaan Menunggu',
            subtitle: 'Sampel slump di sesi produksi muncul di sini '
                'setelah "Catat Slump Test".',
          )
        else
          for (final s in queue)
            QueueCard(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: context.colors.warning.withValues(alpha: 0.12),
                child: Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: context.colors.warning,
                ),
              ),
              title: '${s.produkNama ?? 'Produk'} — ${s.mesinNama ?? 'Mesin'}',
              subtitle:
                  '${qcJenisUjiLabel(s.jenisUji)} ${_fmt(s.nilaiSlump)} mm\n'
                  '${s.titikNama ?? '-'} • '
                  'Sesi ${fmtTanggalWaktu(s.sesiMulai ?? s.createdAt)}',
              statusLabel: qcStatusLabel(s.status),
              statusColor: context.colors.warning,
              badgeLabel: 'Menunggu Uji Tekan',
              badgeColor: context.colors.warning,
              onTap: () => _openInspection(context, s),
            ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => context.push('/qc/riwayat'),
          icon: const Icon(Icons.history_rounded, size: 18),
          label: const Text('Lihat Riwayat QC'),
        ),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary, required this.date});

  final QcHomeSummary summary;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, {Color? color}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$value $label',
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      fmtTanggalPanjang(date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              InfoTooltip(
                message:
                    'Menunggu Pemeriksaan = total sampel "menunggu_hasil" '
                    'dari server.\nSelesai Hari Ini = sampel yang hasilnya '
                    'dicatat BENAR-BENAR pada tanggal hari ini.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              stat(
                'Menunggu Pemeriksaan',
                '${summary.menungguPemeriksaan}',
              ),
              stat(
                'Selesai Hari Ini',
                '${summary.selesaiHariIni}',
                color: const Color(0xFFB9F6CA),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _fmt(double? n) => n == null
    ? '-'
    : n % 1 == 0
    ? n.toInt().toString()
    : n.toStringAsFixed(1);