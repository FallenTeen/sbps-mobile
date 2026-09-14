import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_pill.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class InventoryRequestDetailScreen extends ConsumerStatefulWidget {
  const InventoryRequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<InventoryRequestDetailScreen> createState() =>
      _InventoryRequestDetailScreenState();
}

final _requestDateFormat = DateFormat('dd/MM/yyyy');

class _InventoryRequestDetailScreenState
    extends ConsumerState<InventoryRequestDetailScreen> {
  Future<void> _proses(InventoryRequest request) async {
    final outstanding = request.items
        .where((i) => i.status != InventoryRequestItemStatus.tersedia)
        .map((i) => i.id)
        .toList();
    if (outstanding.isEmpty) return;

    final confirmed = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Proses Request?',
      message:
          'Tandai ${outstanding.length} item sebagai tersedia? Nominal & '
          'catatan pengadaan lama tetap dipertahankan.',
      confirmLabel: 'Proses',
      icon: Icons.inventory_2_outlined,
    );
    if (confirmed?.confirmed != true || !mounted) return;

    final result = await ref
        .read(inventoryProsesProvider.notifier)
        .proses(widget.requestId, outstanding);

    if (!mounted) return;

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses: ${result.error}')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request sparepart diproses')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(inventoryRequestDetailProvider(widget.requestId));
    final prosesState = ref.watch(inventoryProsesProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const BreadcrumbTitle(
          parentLabel: 'Inventory',
          title: 'Detail Request',
        ),
        actions:  [PortalSwitchButton()],
      ),
      body: detailAsync.when(
        loading: () => const SkeletonLoader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBlock(height: 120, borderRadius: 16),
              SizedBox(height: 12),
              SkeletonBlock(height: 72, borderRadius: 14),
              SizedBox(height: 12),
              SkeletonBlock(height: 160, borderRadius: 14),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off_rounded,
                    color: context.colors.error, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Gagal memuat detail request.',
                  style: TextStyle(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref
                      .invalidate(inventoryRequestDetailProvider(widget.requestId)),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (request) {
          final canProses = request.status != InventoryRequestStatus.selesai;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref
                      .invalidate(inventoryRequestDetailProvider(widget.requestId)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HeaderCard(request: request),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.list_alt_rounded,
                              size: 20, color: context.colors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Item Diminta',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final item in request.items)
                        _ItemCard(item: item),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              if (canProses)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton(
                      onPressed: prosesState.busy
                          ? null
                          : () => _proses(request),
                      child: prosesState.busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Proses Request'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.request});

  final InventoryRequest request;

  @override
  Widget build(BuildContext context) {
    final selesai = request.status == InventoryRequestStatus.selesai;

    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus_filled_rounded,
                  color: selesai ? context.colors.success : context.colors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.platNomor,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${request.kategoriServis} \u2022 ${request.totalItems} item',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: request.status.label),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
               Icon(Icons.event_rounded, size: 15, color: context.colors.textMuted),
              const SizedBox(width: 6),
              Text(
                _requestDateFormat.format(request.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textMuted,
                ),
              ),
              SizedBox(width: 16),
               Icon(Icons.sync_alt_rounded, size: 15, color: context.colors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Workshop',
                style: TextStyle(fontSize: 12, color: context.colors.textMuted),
              ),
            ],
          ),
          if (selesai) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.colors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 18, color: context.colors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Semua item sudah tersedia, servis dapat dilanjutkan.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final InventoryRequestItem item;

  Color _statusColor(BuildContext context) => switch (item.status) {
    InventoryRequestItemStatus.tersedia => context.colors.success,
    InventoryRequestItemStatus.kurang => context.colors.warning,
    InventoryRequestItemStatus.tidakTersedia => context.colors.error,
  };

  @override
  Widget build(BuildContext context) {
    final tersedia = item.status == InventoryRequestItemStatus.tersedia;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tersedia
              ? context.colors.success.withValues(alpha: 0.3)
              : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _statusColor(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tersedia ? Icons.check_rounded : Icons.build_rounded,
              size: 19,
              color: _statusColor(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.namaBarang,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.jumlahDiminta} ${item.satuan} diminta',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.status.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _statusColor(context),
                ),
              ),
              if (item.jumlahTersedia != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${item.jumlahTersedia} tersedia',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  Color _color(BuildContext context) => switch (status) {
    'Selesai' => context.colors.success,
    'Diproses' => context.colors.info,
    _ => context.colors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return StatusPill(label: status, color: _color(context));
  }
}
