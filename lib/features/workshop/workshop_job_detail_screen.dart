import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'workshop_models.dart';

class WorkshopJobDetailScreen extends ConsumerStatefulWidget {
  const WorkshopJobDetailScreen({required this.jobId, super.key});

  final String jobId;

  @override
  ConsumerState<WorkshopJobDetailScreen> createState() =>
      _WorkshopJobDetailScreenState();
}

class _WorkshopJobDetailScreenState
    extends ConsumerState<WorkshopJobDetailScreen> {
  bool _isSubmitting = false;

  final _mockJob = WorkshopJob(
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
  );

  late List<WorkshopTodoItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      WorkshopTodoItem(
        id: 't-001',
        jobId: widget.jobId,
        label: 'Filter udara lama dilepas',
        isDone: true,
      ),
      WorkshopTodoItem(
        id: 't-002',
        jobId: widget.jobId,
        label: 'Filter udara baru dipasang',
        isDone: false,
      ),
      WorkshopTodoItem(
        id: 't-003',
        jobId: widget.jobId,
        label: 'Road test & cek tarikan',
        isDone: false,
      ),
    ];
  }

  int get _completedCount => _items.where((i) => i.isDone).length;

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

  void _toggleItem(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(isDone: !_items[index].isDone);
    });
  }

  void _requestSparepart() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur request sparepart akan segera hadir')),
    );
  }

  Future<void> _markComplete() async {
    if (_completedCount < _items.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selesaikan semua item terlebih dahulu'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      AnalyticsService.workshopTodoComplete();
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job berhasil ditandai selesai')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _mockJob;
    final progress =
        job.totalItems > 0 ? _completedCount / job.totalItems : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Job \u2014 ${job.platNomor}'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.kategoriServis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(job.status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _statusLabel(job.status),
                                style: TextStyle(
                                  color: _statusColor(job.status),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Keluhan dari driver:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariantColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            job.keluhan,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppTheme.textTertiary),
                            const SizedBox(width: 6),
                            Text(
                              'Dibuat ${fmtTanggalWaktu(job.createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_completedCount dari ${job.totalItems} item selesai',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: AppTheme.borderColor,
                                  color: progress >= 1.0
                                      ? AppTheme.successColor
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 4,
                                backgroundColor: AppTheme.borderColor,
                                color: progress >= 1.0
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                              ),
                              Text(
                                '${(progress * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Checkbox(
                        value: item.isDone,
                        onChanged: (_) => _toggleItem(index),
                        activeColor: AppTheme.primaryColor,
                      ),
                      title: Text(
                        item.label,
                        style: TextStyle(
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.isDone
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: item.photoPath != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(item.photoPath!),
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          : null,
                      trailing: item.isDone
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.successColor)
                          : IconButton(
                              icon: const Icon(Icons.camera_alt_outlined),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Fitur kamera akan segera hadir'),
                                  ),
                                );
                              },
                              tooltip: 'Ambil foto bukti',
                            ),
                    ),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _requestSparepart,
                      icon: const Icon(Icons.inventory_2_outlined, size: 18),
                      label: const Text('Request Sparepart'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _markComplete,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: const Text('Tandai Selesai'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
