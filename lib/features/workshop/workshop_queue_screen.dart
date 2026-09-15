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
import 'workshop_job_detail_screen.dart';
import 'workshop_models.dart';
import 'workshop_providers.dart';

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
    return switch (_filter) {
      _QueueFilter.menunggu =>
        state.items
            .where((j) => j.status == WorkshopJobStatus.menunggu)
            .toList(),
      _QueueFilter.dikerjakan =>
        state.items
            .where((j) => j.status == WorkshopJobStatus.dikerjakan)
            .toList(),
      _QueueFilter.selesaiHariIni => state.items
          .where(
            (j) =>
                j.status == WorkshopJobStatus.selesai &&
                _isToday(j.completedAt),
          )
          .toList(),
    };
  }

  bool _isToday(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;
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
    final queueState = ref.watch(workshopQueueProvider);
    final filtered = _filteredJobs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrian Workshop'),
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
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: context.colors.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${queueState.menungguCount} menunggu \u00B7 ${queueState.dikerjakanCount} sedang dikerjakan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  InfoTooltip(
                    message:
                        'Urutan pengerjaan mekanik. Tap kartu untuk membuka checklist.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
            Expanded(child: _buildBody(queueState, filtered, onSelect)),
          ],
        ),
        detailBuilder: (context, selectedId) => WorkshopJobDetailContent(
          jobId: selectedId,
          onJobCompleted: () => _masterDetailKey.currentState?.clearSelection(),
        ),
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
      return AppEmptyState(
        icon: Icons.build_circle_outlined,
        title: 'Tidak ada antrian servis',
        subtitle: 'Semua pekerjaan sudah selesai atau belum ada',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(workshopQueueProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final job = filtered[index];
          return QueueCard(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: _statusColor(job.status).withValues(alpha: 0.12),
              child: Icon(
                _statusIcon(job.status),
                size: 20,
                color: _statusColor(job.status),
              ),
            ),
            title: '${job.platNomor} \u2022 ${job.kategoriServis}',
            subtitle: job.keluhan,
            statusLabel: _statusLabel(job.status),
            statusColor: _statusColor(job.status),
            onTap: () => onSelect(job.id),
          );
        },
      ),
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
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
