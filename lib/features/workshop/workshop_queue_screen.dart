import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/adaptive_master_detail.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/brand_strip.dart';
import '../../shared/widgets/info_tooltip.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/queue_card.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../armada/servis_status.dart';
import 'workshop_job_detail_screen.dart';
import 'workshop_models.dart';
import 'workshop_providers.dart';
import 'workshop_rules.dart';

enum _QueueFilter { menunggu, dikerjakan, selesaiHariIni }

class WorkshopQueueScreen extends ConsumerStatefulWidget {
  const WorkshopQueueScreen({super.key, this.initialSelectedId});

  /// Id job awal dari query `?selected=` (deep-link, mode Expanded).
  final String? initialSelectedId;

  @override
  ConsumerState<WorkshopQueueScreen> createState() =>
      _WorkshopQueueScreenState();
}

class _WorkshopQueueScreenState extends ConsumerState<WorkshopQueueScreen> {
  _QueueFilter _filter = _QueueFilter.menunggu;
  final _masterDetailKey = GlobalKey<AdaptiveMasterDetailState>();

  List<WorkshopJob> get _filteredJobs {
    final state = ref.watch(workshopQueueProvider);
    final now = DateTime.now();
    return switch (_filter) {
      _QueueFilter.menunggu =>
        state.items.where((j) => j.status == WorkshopJobStatus.menunggu).toList(),
      _QueueFilter.dikerjakan =>
        state.items.where((j) => j.status == WorkshopJobStatus.dikerjakan).toList(),
      _QueueFilter.selesaiHariIni => selesaiHariIni(state.items, now),
    };
  }

  Color _statusColor(WorkshopJobStatus status) {
    return switch (status) {
      WorkshopJobStatus.menunggu => context.colors.warning,
      WorkshopJobStatus.dikerjakan => context.colors.info,
      WorkshopJobStatus.selesai => context.colors.success,
    };
  }

  String _statusLabel(WorkshopJobStatus status) {
    return switch (status) {
      WorkshopJobStatus.menunggu => 'Menunggu',
      WorkshopJobStatus.dikerjakan => 'Dikerjakan',
      WorkshopJobStatus.selesai => 'Selesai',
    };
  }

  IconData _statusIcon(WorkshopJobStatus status) {
    return switch (status) {
      WorkshopJobStatus.menunggu => Icons.hourglass_empty_rounded,
      WorkshopJobStatus.dikerjakan => Icons.build_rounded,
      WorkshopJobStatus.selesai => Icons.check_circle_outline_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workshop Hari Ini'),
        bottom: const BrandStrip(),
        actions: [PortalSwitchButton()],
      ),
      body: AdaptiveMasterDetail(
        key: _masterDetailKey,
        initialSelectedId: widget.initialSelectedId,
        pushRouteFor: (id) => '/workshop/job/$id',
        emptyDetailPlaceholder: const MasterDetailEmptyPlaceholder(
          icon: Icons.construction_rounded,
          title: 'Pilih job dari antrian',
          subtitle: 'Checklist pekerjaan akan tampil di panel ini',
        ),
        masterBuilder: (context, selectedId, onSelect) => Column(
          children: [
            _buildSummary(context, selectedId, onSelect),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              // Horizontal scroll: 3 label chip tidak muat di layar sempit
              // (~320dp) / text scale 130% — dulu memicu overflow.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('Menunggu', _QueueFilter.menunggu),
                    const SizedBox(width: 8),
                    _buildChip('Sedang Dikerjakan', _QueueFilter.dikerjakan),
                    const SizedBox(width: 8),
                    _buildChip('Selesai Hari Ini', _QueueFilter.selesaiHariIni),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _buildBody(
                ref.watch(workshopQueueProvider),
                _filteredJobs,
                onSelect,
              ),
            ),
          ],
        ),
        detailBuilder: (context, selectedId) => WorkshopJobDetailContent(
          jobId: selectedId,
          onJobCompleted: () => _masterDetailKey.currentState?.clearSelection(),
        ),
      ),
    );
  }

  /// Ringkasan "Workshop Hari Ini" — angka dari status nyata server.
  Widget _buildSummary(
    BuildContext context,
    String? selectedId,
    void Function(String id) onSelect,
  ) {
    final state = ref.watch(workshopQueueProvider);

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

    // Bila status sparepart tidak diketahui, jangan mengaku "0 menunggu".
    final sparepartText = state.sparepartError != null ? '?' : '${state.menungguSparepartCount}';

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
              const Icon(
                Icons.construction_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Workshop Hari Ini',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${state.activeCount} pekerjaan',
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
                message: state.sparepartError != null
                    ? 'Status sparepart sedang tidak bisa dimuat. Coba lagi nanti.\n'
                          'Menunggu Sparepart dihitung dari request inventori yang '
                          'masih pending/diproses untuk job ini.'
                    : 'Jumlah dihitung dari status nyata server.\n'
                          '"Menunggu Sparepart" = job yang punya request inventori '
                          'yang masih pending/diproses.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              stat('Menunggu', '${state.menungguCount}'),
              stat('Dikerjakan', '${state.dikerjakanCount}'),
              stat('Menunggu Sparepart', sparepartText),
              if (state.selesaiHariIniCount > 0)
                stat(
                  'Selesai Hari Ini',
                  '${state.selesaiHariIniCount}',
                  color: const Color(0xFFB9F6CA),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    WorkshopQueueState state,
    List<WorkshopJob> filtered,
    void Function(String id) onSelect,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const SkeletonListView(itemCount: 4);
    }
    if (state.error != null && state.items.isEmpty) {
      return _buildError(state.error!);
    }
    if (filtered.isEmpty) {
      return _buildEmpty();
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(workshopQueueProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final job = filtered[index];
          final waitingSparepart = job.status != WorkshopJobStatus.selesai &&
              state.waitingSparepartJobIds.contains(job.id);
          return QueueCard(
            highlighted: job.id == selectedJobId,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: _statusColor(job.status).withValues(alpha: 0.12),
              child: Icon(
                _statusIcon(job.status),
                size: 20,
                color: _statusColor(job.status),
              ),
            ),
            title:
                '${job.platNomor} \u2022 ${formatKategoriServis(job.kategoriServis)}',
            subtitle: job.keluhan,
            statusLabel: _statusLabel(job.status),
            statusColor: _statusColor(job.status),
            badgeLabel:
                waitingSparepart ? 'Menunggu Sparepart' : null,
            badgeColor: context.colors.warning,
            onTap: () => onSelect(job.id),
          );
        },
      ),
    );
  }

  String? get selectedJobId =>
      _masterDetailKey.currentState?.selectedId;

  Widget _buildEmpty() {
    final (title, subtitle) = switch (_filter) {
      _QueueFilter.menunggu => (
          'Tidak ada pekerjaan menunggu',
          'Semua job sudah diambil atau belum ada antrian baru',
        ),
      _QueueFilter.dikerjakan => (
          'Belum ada pekerjaan dikerjakan',
          'Mulai pengerjaan dari tab Menunggu supaya masuk sini',
        ),
      _QueueFilter.selesaiHariIni => (
          'Belum ada yang selesai hari ini',
          'Job yang ditandai selesai tanggal hari ini tampil di sini',
        ),
    };
    return AppEmptyState(
      icon: Icons.build_circle_outlined,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: context.colors.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(workshopQueueProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, _QueueFilter value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label),
      // Default padded tap target (≥48dp); visual tetap kompak.
      visualDensity: VisualDensity(horizontal: -2, vertical: -2),
      labelPadding: EdgeInsets.symmetric(horizontal: 4),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: context.colors.primary.withValues(alpha: 0.15),
      checkmarkColor: context.colors.primary,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: selected ? context.colors.primary : context.colors.textSecondary,
      ),
    );
  }
}