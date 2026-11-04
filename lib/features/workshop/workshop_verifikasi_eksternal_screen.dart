import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../armada/models/servis_armada.dart';
import '../armada/servis_providers.dart';

/// Layar Verifikasi Servis Eksternal untuk tim Workshop (TD-B7).
/// Workshop dapat melihat daftar servis eksternal dan menandainya
/// "Terverifikasi" atau "Bermasalah" disertai catatan.
class WorkshopVerifikasiEksternalScreen extends ConsumerStatefulWidget {
  const WorkshopVerifikasiEksternalScreen({super.key});

  @override
  ConsumerState<WorkshopVerifikasiEksternalScreen> createState() =>
      _WorkshopVerifikasiEksternalScreenState();
}

class _WorkshopVerifikasiEksternalScreenState
    extends ConsumerState<WorkshopVerifikasiEksternalScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ServisArmada> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ref
          .read(servisRepositoryProvider)
          .getServisEksternalList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = friendlyErrorMessage(
          e,
          fallback: 'Gagal memuat daftar servis eksternal.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _verifikasi(ServisArmada item, String status) async {
    String? catatan;
    if (status == 'bermasalah') {
      final confirm = await ConfirmationDialog.show(
        context,
        severity: ConfirmSeverity.destructive,
        title: 'Tandai Servis Bermasalah?',
        message:
            'Tuliskan catatan masalah atau ketidaksesuaian pada servis ini.',
        confirmLabel: 'Tandai Bermasalah',
        icon: Icons.warning_amber_rounded,
        inputLabel: 'Catatan Masalah *',
        inputRequired: true,
      );
      if (confirm == null || !confirm.confirmed || !mounted) return;
      catatan = confirm.reason;
    } else {
      final confirm = await ConfirmationDialog.show(
        context,
        severity: ConfirmSeverity.warning,
        title: 'Verifikasi Servis Eksternal?',
        message:
            'Apakah Anda yakin pengerjaan bengkel eksternal ini telah sesuai?',
        confirmLabel: 'Verifikasi',
        icon: Icons.check_circle_outline_rounded,
        inputLabel: 'Catatan Tambahan (opsional)',
        inputRequired: false,
      );
      if (confirm == null || !confirm.confirmed || !mounted) return;
      catatan = confirm.reason;
    }

    try {
      await ref.read(servisRepositoryProvider).verifikasiServisEksternal(
            servisId: item.id,
            status: status,
            catatan: catatan,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'terverifikasi'
                ? 'Servis berhasil diverifikasi'
                : 'Servis ditandai bermasalah',
          ),
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              e,
              fallback: 'Gagal memperbarui verifikasi servis.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BreadcrumbTitle(
          parentLabel: 'Workshop',
          title: 'Verifikasi Eksternal',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Gagal Memuat Data',
                        subtitle: _errorMessage,
                        actionLabel: 'Coba Lagi',
                        onAction: _loadData,
                      ),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: AppEmptyState(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Tidak Ada Servis Eksternal',
                            subtitle:
                                'Saat ini tidak ada servis eksternal yang memerlukan verifikasi.',
                            actionLabel: 'Refresh',
                            onAction: _loadData,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return _EksternalCard(
                              item: item,
                              onVerifikasi: (status) =>
                                  _verifikasi(item, status),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}

class _EksternalCard extends StatelessWidget {
  const _EksternalCard({
    required this.item,
    required this.onVerifikasi,
  });

  final ServisArmada item;
  final void Function(String status) onVerifikasi;

  @override
  Widget build(BuildContext context) {
    final verif = item.verifikasiWorkshop?.toLowerCase();
    final (verifLabel, verifColor) = switch (verif) {
      'terverifikasi' => ('Terverifikasi', context.colors.success),
      'bermasalah' => ('Bermasalah', context.colors.error),
      _ => ('Belum Diverifikasi', context.colors.textMuted),
    };

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
                    item.platNomor ?? 'Armada #${item.armadaId}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: verifColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    verifLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: verifColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Bengkel: ${item.namaBengkel ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (item.alamatBengkel != null) ...[
              const SizedBox(height: 2),
              Text(
                item.alamatBengkel!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            if (item.latitude != null && item.longitude != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'GPS: ${item.latitude!.toStringAsFixed(6)}, ${item.longitude!.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.totalBiayaEstimasi != null)
                  Text(
                    'Estimasi: ${fmtRp(item.totalBiayaEstimasi!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (item.totalBiayaResmi != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Resmi: ${fmtRp(item.totalBiayaResmi!)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.success,
                    ),
                  ),
                ],
              ],
            ),
            if (item.fotoBengkelUrl != null &&
                item.fotoBengkelUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.fotoBengkelUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 80,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image, size: 28),
                  ),
                ),
              ),
            ],
            if (item.verifikasiWorkshopCatatan != null &&
                item.verifikasiWorkshopCatatan!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: verifColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: verifColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Catatan: ${item.verifikasiWorkshopCatatan!}',
                  style: TextStyle(fontSize: 12, color: verifColor),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BouncingButton(
                    onPressed: () => onVerifikasi('bermasalah'),
                    child: OutlinedButton.icon(
                      onPressed: () => onVerifikasi('bermasalah'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.colors.error,
                        side: BorderSide(color: context.colors.error),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: const Text('Bermasalah'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BouncingButton(
                    onPressed: () => onVerifikasi('terverifikasi'),
                    child: FilledButton.icon(
                      onPressed: () => onVerifikasi('terverifikasi'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.success,
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Verifikasi'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
