import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/photo_viewer_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'workshop_models.dart';
import 'workshop_providers.dart';

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

  int get _completedCount {
    final detail = ref.read(workshopJobDetailProvider(widget.jobId)).value;
    return detail?.todos.where((t) => t.isDone).length ?? 0;
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

  Future<void> _toggleItem(WorkshopTodoItem item) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(workshopRepositoryProvider)
          .toggleTodoItem(
            jobId: widget.jobId,
            todoId: item.id,
            isDone: !item.isDone,
          );
      ref.invalidate(workshopJobDetailProvider(widget.jobId));
      HapticFeedback.selectionClick();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengubah checklist')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _takeEvidencePhoto(WorkshopTodoItem item) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final photo = await takeWatermarkedPhoto(ref);
      if (photo == null) return;
      await ref
          .read(workshopRepositoryProvider)
          .uploadTodoPhoto(
            jobId: widget.jobId,
            todoId: item.id,
            photoPath: photo.path,
          );
      ref.invalidate(workshopJobDetailProvider(widget.jobId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto bukti terunggah')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil foto')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _requestSparepart() async {
    if (_isSubmitting) return;
    final created = await showRequestSparepartSheet(context);
    if (created == null || created.items.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(workshopRepositoryProvider)
          .requestSparepart(
            jobId: widget.jobId,
            items: created.items,
            catatan: created.catatan,
          );
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sparepart terkirim')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengirim request sparepart')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markComplete(int totalItems) async {
    if (_completedCount < totalItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selesaikan semua item terlebih dahulu')),
      );
      return;
    }

    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.destructive,
      title: 'Tandai Job Selesai?',
      message: 'Job servis ini akan ditutup sebagai selesai dan tidak bisa '
          'diubah lagi. Pastikan semua item & foto bukti sudah lengkap.',
      confirmLabel: 'Ya, Tandai Selesai',
      icon: Icons.check_circle_outline_rounded,
    );
    if (confirm?.confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      AnalyticsService.workshopJobComplete();
      final result = await ref
          .read(workshopSubmitProvider.notifier)
          .tandaiSelesai(jobId: widget.jobId);
      if (result.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error!)),
          );
        }
        return;
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job berhasil ditandai selesai')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(workshopJobDetailProvider(widget.jobId));

    return Scaffold(
      appBar: AppBar(
        title: BreadcrumbTitle(
          parentLabel: 'Antrian Workshop',
          title: 'Job \u2014 ${_titleFor(detailAsync)}',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: detailAsync.when(
        loading: () => const SkeletonDetailView(),
        error: (e, _) => _buildError(e),
        data: (detail) {
          final job = detail.job;
          final items = detail.todos;
          final completed = items.where((t) => t.isDone).length;
          final progress = items.isEmpty ? 0.0 : completed / items.length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoCard(job),
                    const SizedBox(height: 16),
                    _buildProgressCard(progress, completed, items.length),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Belum ada item checklist untuk job ini',
                            style: TextStyle(color: AppTheme.textTertiary),
                          ),
                        ),
                      )
                    else
                      ...List.generate(items.length, (index) {
                        final item = items[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Checkbox(
                              value: item.isDone,
                              onChanged: _isSubmitting
                                  ? null
                                  : (_) => _toggleItem(item),
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
                                    child: InkWell(
                                      onTap: () => PhotoViewerDialog.show(
                                        context: context,
                                        heroTag: 'todo-photo-${item.id}',
                                        imageUrl: item.photoPath,
                                        title: item.label,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _networkOrFilePhoto(item.photoPath!),
                                      ),
                                    ),
                                  )
                                : null,
                            trailing: item.isDone
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppTheme.successColor,
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.camera_alt_outlined),
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _takeEvidencePhoto(item),
                                    tooltip: 'Ambil foto bukti',
                                  ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              SafeArea(
                child: job.status == WorkshopJobStatus.selesai
                    ? Container(
                        width: double.infinity,
                        color: AppTheme.successColor.withValues(alpha: 0.08),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                              color: AppTheme.successColor,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Job servis telah selesai dikerjakan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.successColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _requestSparepart(),
                                icon: const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                ),
                                label: const Text('Request Sparepart'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _markComplete(items.length),
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
          );
        },
      ),
    );
  }

  Widget _networkOrFilePhoto(String path) {
    if (path.startsWith('http') || path.startsWith('https')) {
      return Image.network(
        path,
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          height: 60,
          width: 60,
          color: AppTheme.surfaceVariantColor,
          child: const Icon(Icons.broken_image_outlined,
              size: 24, color: AppTheme.textTertiary),
        ),
      );
    }
    return Image.file(
      File(path),
      height: 60,
      width: 60,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 60,
        width: 60,
        color: AppTheme.surfaceVariantColor,
        child: const Icon(Icons.broken_image_outlined,
            size: 24, color: AppTheme.textTertiary),
      ),
    );
  }

  String _titleFor(AsyncValue<WorkshopJobDetail> detailAsync) {
    return detailAsync.value?.job.platNomor ?? 'Loading...';
  }

  Widget _buildInfoCard(WorkshopJob job) {
    return Card(
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
                StatusPill(
                  label: _statusLabel(job.status),
                  color: _statusColor(job.status),
                  filled: job.status == WorkshopJobStatus.selesai,
                  borderRadius: 16,
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
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppTheme.textTertiary,
                ),
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
    );
  }

  Widget _buildProgressCard(double progress, int completed, int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$completed dari $total item selesai',
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
    );
  }

  Widget _buildError(Object error) {
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
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.invalidate(workshopJobDetailProvider(widget.jobId)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hasil input sheet request sparepart.
class SparepartSheetResult {
  const SparepartSheetResult({required this.items, this.catatan});

  final List<SparepartRequestItem> items;
  final String? catatan;
}

/// Bottom sheet untuk menambah item sparepart yang diminta dari konteks job.
Future<SparepartSheetResult?> showRequestSparepartSheet(
  BuildContext context,
) async {
  final items = <({String nama, int jumlah, String? satuan, String? keterangan})>[
    (nama: '', jumlah: 1, satuan: null, keterangan: null),
  ];
  final catatanController = TextEditingController();

  return showModalBottomSheet<SparepartSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void addRow() {
            setSheetState(() => items.add(
                  (nama: '', jumlah: 1, satuan: null, keterangan: null),
                ));
          }

          void submit() {
            final valid = items
                .where((i) => i.nama.trim().isNotEmpty)
                .map((i) => SparepartRequestItem(
                      namaBarang: i.nama.trim(),
                      jumlah: i.jumlah,
                      satuan: i.satuan?.isEmpty ?? true ? null : i.satuan,
                      keterangan:
                          i.keterangan?.isEmpty ?? true ? null : i.keterangan,
                    ))
                .toList();
            if (valid.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Isi minimal satu item')),
              );
              return;
            }
            Navigator.of(context).pop(
              SparepartSheetResult(
                items: valid,
                catatan: catatanController.text.trim().isEmpty
                    ? null
                    : catatanController.text.trim(),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Request Sparepart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih sparepart yang dibutuhkan untuk job ini',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < items.length; i++) _buildItemRow(
                    context,
                    items,
                    i,
                    setSheetState,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: addRow,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah Item'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: catatanController,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: submit,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Kirim Request'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildItemRow(
  BuildContext context,
  List<({String nama, int jumlah, String? satuan, String? keterangan})> items,
  int index,
  StateSetter setSheetState,
) {
  void update({
    String? nama,
    int? jumlah,
    String? satuan,
    String? keterangan,
  }) {
    setSheetState(() {
      final old = items[index];
      items[index] = (
        nama: nama ?? old.nama,
        jumlah: jumlah ?? old.jumlah,
        satuan: satuan,
        keterangan: keterangan,
      );
    });
  }

  return Row(
    children: [
      Expanded(
        child: TextField(
          decoration: InputDecoration(
            labelText: 'Nama barang',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => update(nama: v),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 68,
        child: TextFormField(
          decoration: InputDecoration(
            labelText: 'Qty',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: items[index].jumlah.toString(),
          onChanged: (v) => update(jumlah: int.tryParse(v) ?? 1),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor),
        onPressed: items.length == 1
            ? null
            : () =>
                setSheetState(() => items.removeAt(index)),
        tooltip: 'Hapus item',
      ),
    ],
  );
}