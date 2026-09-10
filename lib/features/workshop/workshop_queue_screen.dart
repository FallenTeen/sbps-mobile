import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/queue_card.dart';
import 'workshop_models.dart';

enum _QueueFilter { menunggu, dikerjakan, selesaiHariIni }

class WorkshopQueueScreen extends ConsumerStatefulWidget {
  const WorkshopQueueScreen({super.key});

  @override
  ConsumerState<WorkshopQueueScreen> createState() =>
      _WorkshopQueueScreenState();
}

class _WorkshopQueueScreenState extends ConsumerState<WorkshopQueueScreen> {
  _QueueFilter _filter = _QueueFilter.menunggu;

  final List<WorkshopJob> _mockJobs = [
    WorkshopJob(
      id: 'wj-001',
      armadaId: 'arm-10',
      platNomor: 'DK 1234 AB',
      kategoriServis: 'Ganti Oli',
      keluhan: 'Mesin suara kasar, oli sudah hitam pekat dan berbau terbakar',
      status: WorkshopJobStatus.menunggu,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      totalItems: 4,
      completedItems: 0,
    ),
    WorkshopJob(
      id: 'wj-002',
      armadaId: 'arm-05',
      platNomor: 'DK 5678 CD',
      kategoriServis: 'Servis Rem',
      keluhan: 'Rem belakang kurang pakem, pedal rem agak jauh',
      status: WorkshopJobStatus.menunggu,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      totalItems: 6,
      completedItems: 0,
    ),
    WorkshopJob(
      id: 'wj-003',
      armadaId: 'arm-22',
      platNomor: 'DK 9012 EF',
      kategoriServis: 'Ganti Filter',
      keluhan: 'Tarikan berat, filter udara sudah kotor maksimal',
      status: WorkshopJobStatus.dikerjakan,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      assignedAt: DateTime.now().subtract(const Duration(hours: 3)),
      totalItems: 3,
      completedItems: 1,
    ),
    WorkshopJob(
      id: 'wj-004',
      armadaId: 'arm-08',
      platNomor: 'DK 3456 GH',
      kategoriServis: 'Overhaul Ringan',
      keluhan: 'Mesin overheat, thermostat perlu diganti',
      status: WorkshopJobStatus.dikerjakan,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      assignedAt: DateTime.now().subtract(const Duration(hours: 5)),
      totalItems: 8,
      completedItems: 5,
    ),
    WorkshopJob(
      id: 'wj-005',
      armadaId: 'arm-15',
      platNomor: 'DK 7890 IJ',
      kategoriServis: 'Servis Ringan',
      keluhan: 'Servis rutin 5000 km, ganti oli dan filter',
      status: WorkshopJobStatus.selesai,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      assignedAt: DateTime.now().subtract(const Duration(days: 1)),
      completedAt: DateTime.now().subtract(const Duration(hours: 4)),
      totalItems: 5,
      completedItems: 5,
    ),
  ];

  List<WorkshopJob> get _filteredJobs {
    return _mockJobs.where((j) {
      return switch (_filter) {
        _QueueFilter.menunggu => j.status == WorkshopJobStatus.menunggu,
        _QueueFilter.dikerjakan => j.status == WorkshopJobStatus.dikerjakan,
        _QueueFilter.selesaiHariIni => j.status == WorkshopJobStatus.selesai,
      };
    }).toList();
  }

  int get _menungguCount =>
      _mockJobs.where((j) => j.status == WorkshopJobStatus.menunggu).length;

  int get _dikerjakanCount =>
      _mockJobs.where((j) => j.status == WorkshopJobStatus.dikerjakan).length;

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
              '$_menungguCount menunggu \u00B7 $_dikerjakanCount sedang dikerjakan',
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
            child: filtered.isEmpty
                ? AppEmptyState(
                    icon: Icons.build_circle_outlined,
                    title: 'Tidak ada antrian servis',
                    subtitle: 'Semua pekerjaan sudah selesai atau belum ada',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final job = filtered[index];
                      return QueueCard(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: _statusColor(
                            job.status,
                          ).withValues(alpha: 0.12),
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
          ),
        ],
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
