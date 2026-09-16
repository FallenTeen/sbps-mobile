import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/outbox/pending_action.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../presensi/presensi_providers.dart';

class DataBelumTerkirimScreen extends ConsumerStatefulWidget {
  const DataBelumTerkirimScreen({super.key});

  @override
  ConsumerState<DataBelumTerkirimScreen> createState() =>
      _DataBelumTerkirimScreenState();
}

class _DataBelumTerkirimScreenState
    extends ConsumerState<DataBelumTerkirimScreen> {
  Future<void> _retry(PendingAction action) async {
    final repository = ref.read(outboxRepositoryProvider);
    await repository.markPending(action.id);
    await ref.read(outboxSyncServiceProvider).syncNow(ignoreBackoff: true);
    ref.invalidate(pendingActionsProvider);
  }

  Future<void> _remove(PendingAction action) async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.destructive,
      title: 'Hapus data ini secara permanen?',
      message:
          'Aksi ini belum pernah terkirim ke server. Jika dihapus, data '
          'dan foto yang sudah diambil akan hilang total dan tidak bisa '
          'dikembalikan.',
      confirmLabel: 'Ya, Hapus Permanen',
      icon: Icons.delete_forever_rounded,
    );
    if (confirm?.confirmed != true || !mounted) return;
    await ref.read(outboxRepositoryProvider).remove(action.id);
    ref.invalidate(pendingActionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(pendingActionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Data Belum Terkirim')),
      body: actions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal membuka antrean',
          subtitle: friendlyErrorMessage(error),
          actionLabel: 'Coba lagi',
          onAction: () => ref.invalidate(pendingActionsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.cloud_done_outlined,
              title: 'Semua data sudah terkirim',
              subtitle:
                  'Aksi yang belum tersinkron akan tampil di sini untuk dikirim ulang.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(pendingActionsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _PendingActionTile(
                action: items[index],
                onRetry: () => _retry(items[index]),
                onRemove: () => _remove(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingActionTile extends StatelessWidget {
  const _PendingActionTile({
    required this.action,
    required this.onRetry,
    required this.onRemove,
  });

  final PendingAction action;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  String get _label => switch (action.endpoint) {
    PendingEndpoint.presensiCheckIn => 'Check-in presensi',
    PendingEndpoint.presensiCheckOut => 'Check-out presensi',
    PendingEndpoint.formulirSubmit => 'Formulir lapangan',
    PendingEndpoint.produksiMulai => 'Mulai sesi produksi',
    PendingEndpoint.produksiSelesai => 'Selesai sesi produksi',
    PendingEndpoint.qcSlumpTest => 'Uji slump QC',
    PendingEndpoint.qcUjiTekan => 'Uji tekan QC',
    PendingEndpoint.uploadMedia => 'Dokumentasi foto',
    PendingEndpoint.helperPresensi => 'Presensi helper',
    PendingEndpoint.armadaChecklist => 'Checklist armada',
    PendingEndpoint.armadaChecklistMajor => 'Checklist major armada',
    PendingEndpoint.armadaOdoAwal => 'ODO awal proyek',
    PendingEndpoint.armadaRitase => 'Ritase armada',
    PendingEndpoint.workshopMulai => 'Mulai kerja workshop',
    PendingEndpoint.workshopSelesai => 'Selesai servis workshop',
    PendingEndpoint.inventoryOpname => 'Stok opname inventory',
  };

  String get _status => switch (action.status) {
    PendingStatus.pending => 'Menunggu jaringan',
    PendingStatus.syncing => 'Sedang mengirim',
    PendingStatus.failed => 'Gagal dikirim',
    PendingStatus.success => 'Terkirim',
  };

  Color _statusColor(BuildContext context) => switch (action.status) {
    PendingStatus.pending => Colors.orange.shade800,
    PendingStatus.syncing => Theme.of(context).colorScheme.primary,
    PendingStatus.failed => Theme.of(context).colorScheme.error,
    PendingStatus.success => Colors.green.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  _status,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(action.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (action.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                action.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (action.status == PendingStatus.failed) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Kirim Ulang'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
