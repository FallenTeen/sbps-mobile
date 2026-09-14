import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/api_client.dart';
import '../auth/auth_providers.dart';
import 'servis_providers.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../core/formatters.dart';

/// Detail Pengajuan Servis Armada beserta riwayat sparepart, catatan workshop,
/// dan aksi persetujuan/penolakan untuk Kepala Divisi/Admin.
class DetailServisScreen extends ConsumerStatefulWidget {
  const DetailServisScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<DetailServisScreen> createState() => _DetailServisScreenState();
}

class _DetailServisScreenState extends ConsumerState<DetailServisScreen> {
  bool _isProcessing = false;

  Color _statusColor(String status) {
    return switch (status) {
      'diajukan' => Colors.orange,
      'disetujui' => Colors.blue,
      'dikerjakan' => Colors.purple,
      'selesai' => Colors.green,
      'ditolak' => Colors.red,
      _ => Colors.grey,
    };
  }

  String _statusLabel(String status) {
    return switch (status) {
      'diajukan' => 'Menunggu Persetujuan',
      'disetujui' => 'Disetujui',
      'dikerjakan' => 'Sedang Dikerjakan',
      'selesai' => 'Selesai',
      'ditolak' => 'Ditolak',
      _ => status,
    };
  }

  Future<void> _approveServis() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Setujui Pengajuan Servis?',
      message: 'Pengajuan servis akan diteruskan ke tim workshop untuk '
          'dikerjakan.',
      confirmLabel: 'Setujui',
      icon: Icons.check_circle_outline_rounded,
      inputLabel: 'Catatan Persetujuan (opsional)',
      inputRequired: false,
    );

    if (confirm == null || !confirm.confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(servisRepositoryProvider).approveServis(
            id: widget.id,
            catatan: (confirm.reason?.isEmpty ?? true)
                ? null
                : confirm.reason!.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis berhasil disetujui')),
      );
      ref.invalidate(detailServisProvider(widget.id));
      ref.read(servisRiwayatProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _tolakServis() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.destructive,
      title: 'Tolak Pengajuan Servis?',
      message: 'Pengajuan ini akan ditolak dan berstatus "Ditolak" secara '
          'permanen. Alasan wajib diisi sebagai catatan keputusan.',
      confirmLabel: 'Tolak Pengajuan',
      icon: Icons.block_rounded,
      inputLabel: 'Alasan Penolakan *',
      inputRequired: true,
    );

    if (confirm == null || !confirm.confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(servisRepositoryProvider).tolakServis(
            id: widget.id,
            alasan: confirm.reason ?? '',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan servis ditolak')),
      );
      ref.invalidate(detailServisProvider(widget.id));
      ref.read(servisRiwayatProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(detailServisProvider(widget.id));
    final activeRole = ref.watch(activeRoleProvider);
    final canApprove = activeRole == 'Owner' ||
        activeRole == 'Admin Keuangan' ||
        activeRole == 'Kepala Divisi Armada' ||
        activeRole == 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const BreadcrumbTitle(
          parentLabel: 'Armada',
          title: 'Detail Servis',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: detailAsync.when(
          loading: () => const SkeletonDetailView(),
          error: (error, _) => Center(
            child: AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Gagal Memuat Detail Servis',
              subtitle: '$error',
              actionLabel: 'Coba Lagi',
              onAction: () =>
                  ref.invalidate(detailServisProvider(widget.id)),
            ),
          ),
          data: (item) {
            final color = _statusColor(item.status);

            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(detailServisProvider(widget.id)),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                // Header Status Card
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
                                item.platNomor ?? 'Armada #${item.armadaId}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _statusLabel(item.status),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.kodeUnit != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Unit: ${item.kodeUnit!} • Jenis: ${item.jenisArmada ?? '-'}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Data Pengajuan
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Pengajuan',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(height: 20),
                        _infoRow('Tanggal Ajuan', fmtTanggal(item.tanggalAjuan)),
                        if (item.kategori != null)
                          _infoRow('Kategori', item.kategori!),
                        if (item.odometerSaatAjuan != null)
                          _infoRow(
                            'ODO Saat Ajuan',
                            fmtKm(item.odometerSaatAjuan),
                          ),
                        if (item.jamOperasionalSaatAjuan != null)
                          _infoRow(
                            'Jam Operasional',
                            fmtJam(item.jamOperasionalSaatAjuan),
                          ),
                        if (item.diajukanOleh != null)
                          _infoRow('Diajukan Oleh', item.diajukanOleh!),
                        if (item.disetujuiOleh != null)
                          _infoRow('Disetujui Oleh', item.disetujuiOleh!),
                        const SizedBox(height: 8),
                        const Text(
                          'Keluhan / Masalah:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(item.keluhan),
                        ),
                        if (item.alasanPenolakan != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Alasan Penolakan:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(item.alasanPenolakan!),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Sparepart yang digunakan (jika ada)
                if (item.spareparts.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sparepart Digunakan',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Chip(
                                label: Text('${item.spareparts.length} item'),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          for (final part in item.spareparts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      part.namaBarang,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${part.jumlah.toStringAsFixed(0)} ${part.satuan ?? 'pcs'}',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (item.totalBiaya != null) ...[
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Biaya:',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                  Text(
                                    fmtRp(item.totalBiaya!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons for Approval (if status is 'diajukan' and role allows)
                if (item.isMenungguApproval && canApprove) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: BouncingButton(
                          onPressed: _isProcessing ? null : _tolakServis,
                          child: OutlinedButton.icon(
                            onPressed: _isProcessing ? null : _tolakServis,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Tolak'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BouncingButton(
                          onPressed: _isProcessing ? null : _approveServis,
                          child: FilledButton.icon(
                            onPressed: _isProcessing ? null : _approveServis,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Setujui'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
