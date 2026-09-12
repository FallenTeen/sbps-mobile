import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/queue_card.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'workshop_models.dart';
import 'workshop_providers.dart';

enum _QueueFilter { menunggu, dikerjakan, selesaiHariIni }

class WorkshopQueueScreen extends ConsumerStatefulWidget {
  const WorkshopQueueScreen({super.key});

  @override
  ConsumerState<WorkshopQueueScreen> createState() => _WorkshopQueueScreenState();
}

class _WorkshopQueueScreenState extends ConsumerState<WorkshopQueueScreen> {
  _QueueFilter _filter = _QueueFilter.menunggu;

  List<WorkshopJob> get _filteredJobs {
    final state = ref.watch(workshopQueueProvider);
    return switch (_filter) {
      _QueueFilter.menunggu =>
        state.items.where((j) => j.status == WorkshopJobStatus.menunggu).toList(),
      _QueueFilter.dikerjakan =>
        state.items.where((j) => j.status == WorkshopJobStatus.dikerjakan).toList(),
      _QueueFilter.selesaiHariIni =>
        state.items.where((j) => j.status == WorkshopJobStatus.selesai).toList(),
    };
  }

  Color _statusColor(WorkshopJobStatus status) {
    return switch (status) {
      WorkshopJobStatus.menunggu => AppTheme.warningColor,
      WorkshopJobStatus.dikerjakan => AppTheme.infoColor,
      WorkshopJobStatus.selesai => AppTheme.successColor,
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
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            child: Text(
              '${queueState.menungguCount} menunggu \u00B7 ${queueState.dikerjakanCount} sedang dikerjakan',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
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
          Expanded(
            child: _buildBody(queueState, filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(WorkshopQueueState state, List<WorkshopJob> filtered) {
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
      onRefresh: () =>
          ref.read(workshopQueueProvider.notifier).refresh(),
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
            onTap: () => context.push('/workshop/job/${job.id}'),
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
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.read(workshopQueueProvider.notifier).refresh(),
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
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      checkmarkColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
      ),
    );
  }
}