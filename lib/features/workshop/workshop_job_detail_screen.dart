import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/photo_viewer_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_pill.dart';
import '../../shared/widgets/submit_spinner.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../armada/servis_status.dart';
import '../armada/models/servis_armada.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import 'workshop_models.dart';
import 'workshop_providers.dart';
import 'workshop_rules.dart';

/// Screen detail job workshop (full-page) — membungkus
/// [WorkshopJobDetailContent] dengan Scaffold + AppBar.
/// Dipakai route push di Compact/Medium.
class WorkshopJobDetailScreen extends ConsumerWidget {
  const WorkshopJobDetailScreen({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(workshopJobDetailProvider(jobId));
    return Scaffold(
      appBar: AppBar(
        title: BreadcrumbTitle(
          parentLabel: 'Antrian Workshop',
          title:
              'Job \u2014 ${detailAsync.value?.job.platNomor ?? 'Loading...'}',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: WorkshopJobDetailContent(jobId: jobId),
    );
  }
}

/// Konten detail job workshop tanpa Scaffold/AppBar — dipakai sebagai
/// body full-page (lewat [WorkshopJobDetailScreen]) maupun panel kanan
/// [AdaptiveMasterDetail] saat Expanded.
class WorkshopJobDetailContent extends ConsumerStatefulWidget {
  const WorkshopJobDetailContent({
    required this.jobId,
    this.onJobCompleted,
    super.key,
  });

  final String jobId;

  /// Dipanggil setelah job berhasil ditandai selesai saat mode embedded
  /// (panel kanan AdaptiveMasterDetail) — menggantikan `context.pop()`.
  final VoidCallback? onJobCompleted;

  @override
  ConsumerState<WorkshopJobDetailContent> createState() =>
      _WorkshopJobDetailContentState();
}

class _WorkshopJobDetailContentState
    extends ConsumerState<WorkshopJobDetailContent> {
  bool _isSubmitting = false;

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
    final key = '${widget.jobId}|${item.id}';
    if (ref.read(pendingWorkshopTodoPhotoProvider(key))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Foto bukti masih menunggu sinkron — lihat Data Belum '
              'Terkirim sampai foto sebelumnya terkirim.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final photo = await takeWatermarkedPhoto(ref);
      if (photo == null) return;
      final result = await ref
          .read(workshopRepositoryProvider)
          .uploadTodoPhoto(
            jobId: widget.jobId,
            todoId: item.id,
            photoPath: photo.path,
          );
      ref.invalidate(workshopJobDetailProvider(widget.jobId));
      if (mounted) {
        final message = result.delivered
            ? 'Foto bukti terunggah'
            : result.permanentlyFailed
            ? (result.errorMessage ?? 'Gagal mengunggah foto bukti')
            : kCopyQueued;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal mengambil foto')));
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
      final result = await ref
          .read(workshopRepositoryProvider)
          .requestSparepart(
            jobId: widget.jobId,
            items: created.items,
            catatan: created.catatan,
          );
      if (result.delivered) {
        ref.invalidate(workshopQueueProvider);
        ref.invalidate(inventoryRequestsProvider);
        if (mounted) {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request sparepart terkirim')),
          );
        }
      } else if (result.permanentlyFailed) {
        // 4xx: aksi ditandai "Gagal dikirim" di outbox — jangan tampilkan
        // sebagai "tersimpan/menunggu" (queued ≠ server success, §16/§31).
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ?? 'Gagal mengirim request sparepart',
              ),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kCopyQueued)),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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

  Future<void> _startWork() async {
    setState(() => _isSubmitting = true);
    try {
      final result = await ref
          .read(workshopSubmitProvider.notifier)
          .mulaiPengerjaan(widget.jobId);
      if (result.error != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.error!)));
        }
        return;
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (result.delivered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengerjaan dimulai — job masuk Dikerjakan.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kCopyQueued)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markComplete(List<WorkshopTodoItem> todos) async {
    final status = ref
        .read(workshopJobDetailProvider(widget.jobId))
        .value
        ?.job
        .status;
    if (status == null) return;

    final check = workshopCanComplete(status: status, todos: todos);
    if (!check.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(check.reason ?? 'Belum bisa menandai selesai')),
      );
      return;
    }

    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.destructive,
      title: 'Tandai Job Selesai?',
      message:
          'Job servis ini akan ditutup sebagai selesai dan tidak bisa '
          'diubah lagi. Pastikan semua item pekerjaan sudah selesai dan '
          'foto bukti sudah lengkap.',
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result.error!)));
        }
        return;
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (result.delivered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job berhasil ditandai selesai')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kCopyQueued)),
        );
      }
      if (widget.onJobCompleted != null) {
        ref.read(workshopQueueProvider.notifier).refresh();
        widget.onJobCompleted!();
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(workshopJobDetailProvider(widget.jobId));
    final requestsAsync = ref.watch(inventoryRequestsProvider);

    return detailAsync.when(
      loading: () => SkeletonDetailView(),
      error: (e, _) => _buildError(e),
      data: (detail) {
        final job = detail.job;
        final servis = detail.servis;
        final items = detail.todos;
        final completed = workshopCompletedCount(items);
        final progress = items.isEmpty ? 0.0 : completed / items.length;
        final waitingRequests = _waitingRequests(requestsAsync, widget.jobId);
        final waitingSparepart = waitingRequests.isNotEmpty;

        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(workshopJobDetailProvider(widget.jobId));
                  ref.invalidate(inventoryRequestsProvider);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoCard(job, servis, waitingSparepart: waitingSparepart),
                    const SizedBox(height: 16),
                    _buildProgressCard(progress, completed, items.length),
                    const SizedBox(height: 16),
                    _buildTodoSection(items),
                    const SizedBox(height: 16),
                    _buildSparepartSection(servis, waitingRequests),
                  ],
                ),
              ),
            ),
            SafeArea(child: _buildBottomBar(job, items, waitingSparepart)),
          ],
        );
      },
    );
  }

  /// Request sparepart yang belum selesai untuk job ini.
  List<InventoryRequest> _waitingRequests(
    AsyncValue<List<InventoryRequest>> requestsAsync,
    String jobId,
  ) {
    final requests = requestsAsync.value;
    if (requests == null) return const [];
    return requests
        .where(
          (r) =>
              r.workshopJobId == jobId &&
              (r.status == InventoryRequestStatus.pending ||
                  r.status == InventoryRequestStatus.diproses),
        )
        .toList();
  }

  Widget _buildBottomBar(
    WorkshopJob job,
    List<WorkshopTodoItem> items,
    bool waitingSparepart,
  ) {
    if (job.status == WorkshopJobStatus.selesai) {
      return Container(
        width: double.infinity,
        color: context.colors.success.withValues(alpha: 0.08),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: context.colors.success,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Job servis telah selesai dikerjakan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.success,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (job.status == WorkshopJobStatus.menunggu) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _startWork,
            icon: _isSubmitting
                ? const SubmitSpinner(size: 18)
                : const Icon(Icons.play_arrow, size: 20),
            label: Text('Mulai Pengerjaan'),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (waitingSparepart)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Masih menunggu sparepart dari inventori — '
                'pastikan request sudah beres sebelum Tandai Selesai.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.warning,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _requestSparepart,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Request Sparepart'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isSubmitting
                      ? null
                      : () => _markComplete(items),
                  icon: _isSubmitting
                      ? const SubmitSpinner(size: 18)
                      : const Icon(Icons.check, size: 18),
                  label: Text('Tandai Selesai'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodoSection(List<WorkshopTodoItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Todo Pekerjaan',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              'Belum ada item pekerjaan untuk job ini — job tidak bisa '
              'ditandai selesai tanpa item. Hubungi admin servis.',
              style: TextStyle(fontSize: 13, color: context.colors.textTertiary),
            ),
          )
        else
          ...List.generate(items.length, (index) {
            final item = items[index];
            final pendingPhoto = ref.watch(
              pendingWorkshopTodoPhotoProvider('${widget.jobId}|${item.id}'),
            );
            return Card(
              margin: EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                child: ListTile(
                  leading: Checkbox(
                    value: item.isDone,
                    onChanged: _isSubmitting ? null : (_) => _toggleItem(item),
                    activeColor: context.colors.primary,
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      decoration: item.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.isDone
                          ? context.colors.textTertiary
                          : context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: item.photoPath != null
                      ? Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              InkWell(
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
                              const SizedBox(width: 8),
                              Text(
                                'Foto bukti',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                  trailing: IconButton(
                    icon: Icon(Icons.camera_alt_outlined),
                    onPressed: _isSubmitting || pendingPhoto
                        ? null
                        : () => _takeEvidencePhoto(item),
                    tooltip: pendingPhoto
                        ? 'Foto bukti menunggu sinkron'
                        : 'Ambil ${item.isDone ? 'ulang' : ''} foto bukti',
                    color: pendingPhoto
                        ? context.colors.warning
                        : item.photoPath != null
                        ? context.colors.success
                        : null,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _networkOrFilePhoto(String path) {
    if (path.startsWith('http') || path.startsWith('https')) {
      return Image.network(
        path,
        height: 52,
        width: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brokenPhotoBox(),
      );
    }
    return Image.file(
      File(path),
      height: 52,
      width: 52,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _brokenPhotoBox(),
    );
  }

  Widget _brokenPhotoBox() {
    return Container(
      height: 52,
      width: 52,
      color: context.colors.surfaceVariant,
      child: Icon(
        Icons.broken_image_outlined,
        size: 24,
        color: context.colors.textTertiary,
      ),
    );
  }

  Widget _buildInfoCard(
    WorkshopJob job,
    ServisArmada servis, {
    required bool waitingSparepart,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.platNomor,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatKategoriServis(job.kategoriServis),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
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
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  waitingSparepart
                      ? Icons.inventory_2_outlined
                      : Icons.next_plan_outlined,
                  size: 15,
                  color: waitingSparepart
                      ? context.colors.warning
                      : context.colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    workshopNextAction(
                      job,
                      waitingSparepart: waitingSparepart,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: waitingSparepart
                          ? context.colors.warning
                          : context.colors.textSecondary,
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
                color: context.colors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                job.keluhan.isEmpty ? '-' : job.keluhan,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(
              Icons.person_outline_rounded,
              'Pengaju',
              servis.diajukanOleh ?? '-',
            ),
            _infoRow(
              Icons.calendar_today_outlined,
              'Dibuat',
              fmtTanggalWaktu(job.createdAt),
            ),
            if (servis.tanggalSelesai != null)
              _infoRow(
                Icons.event_available_outlined,
                'Selesai',
                fmtTanggalWaktu(job.completedAt),
              ),
            if (servis.odometerSaatAjuan != null)
              _infoRow(
                Icons.speed_rounded,
                'ODO saat ajuan',
                fmtKm(servis.odometerSaatAjuan),
              ),
            if (servis.jamOperasionalSaatAjuan != null)
              _infoRow(
                Icons.schedule_rounded,
                'Jam operasional',
                fmtJam(servis.jamOperasionalSaatAjuan),
              ),
            if (servis.kodeUnit != null && servis.kodeUnit!.isNotEmpty)
              _infoRow(Icons.tag_rounded, 'Kode unit', servis.kodeUnit!),
            if (servis.catatanWorkshop != null &&
                servis.catatanWorkshop!.isNotEmpty)
              _infoRow(
                Icons.sticky_note_2_outlined,
                'Catatan workshop',
                servis.catatanWorkshop!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: context.colors.textTertiary),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.textTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(double progress, int completed, int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$completed dari $total item selesai',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: context.colors.border,
                color: progress >= 1.0
                    ? context.colors.success
                    : context.colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparepartSection(
    ServisArmada servis,
    List<InventoryRequest> waitingRequests,
  ) {
    final used = servis.spareparts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 18, color: context.colors.primary),
            const SizedBox(width: 8),
            Text(
              'Sparepart',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            if (waitingRequests.isNotEmpty)
              StatusPill(
                label: 'Menunggu Sparepart',
                color: context.colors.warning,
                borderRadius: 12,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (waitingRequests.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.colors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in waitingRequests)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${r.totalItems} item diminta — status ${r.status.label} '
                      '(request #${r.id})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                Text(
                  'Belum disediakan inventori. Job bisa tetap dikerjakan, '
                  'tapi pastikan sparepart beres sebelum selesai.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        if (used.isEmpty && waitingRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Belum ada request sparepart untuk job ini.',
              style: TextStyle(fontSize: 13, color: context.colors.textTertiary),
            ),
          ),
        if (used.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sparepart digunakan:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                for (final p in used)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• ${p.namaBarang} × ${fmtNum(p.jumlah)}'
                      '${p.satuan != null ? ' ${p.satuan}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildError(Object error) {
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
              friendlyErrorMessage(error),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textSecondary,
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
  final items =
      <({String nama, int jumlah, String? satuan, String? keterangan})>[
        (nama: '', jumlah: 1, satuan: null, keterangan: null),
      ];
  final catatanController = TextEditingController();

  return showModalBottomSheet<SparepartSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          void addRow() {
            setSheetState(
              () => items.add((
                nama: '',
                jumlah: 1,
                satuan: null,
                keterangan: null,
              )),
            );
          }

          void submit() {
            final valid = items
                .where((i) => i.nama.trim().isNotEmpty)
                .map(
                  (i) => SparepartRequestItem(
                    namaBarang: i.nama.trim(),
                    jumlah: i.jumlah,
                    satuan: i.satuan?.isEmpty ?? true ? null : i.satuan,
                    keterangan: i.keterangan?.isEmpty ?? true
                        ? null
                        : i.keterangan,
                  ),
                )
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
                  Text(
                    'Request Sparepart',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih sparepart yang dibutuhkan untuk job ini',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textTertiary,
                    ),
                  ),
                  SizedBox(height: 16),
                  for (var i = 0; i < items.length; i++)
                    _buildItemRow(context, items, i, setSheetState),
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
  void update({String? nama, int? jumlah, String? satuan, String? keterangan}) {
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
      SizedBox(width: 8),
      IconButton(
        icon: Icon(Icons.remove_circle_outline, color: context.colors.error),
        onPressed: items.length == 1
            ? null
            : () => setSheetState(() => items.removeAt(index)),
        tooltip: 'Hapus item',
      ),
    ],
  );
}