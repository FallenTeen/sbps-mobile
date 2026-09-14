import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/brand_strip.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/queue_card.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class InventoryHomeScreen extends ConsumerStatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  ConsumerState<InventoryHomeScreen> createState() =>
      _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends ConsumerState<InventoryHomeScreen> {
  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(inventorySummaryProvider);
    final requestsAsync = ref.watch(inventoryRequestsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: const BrandStrip(),
        actions:  [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inventorySummaryProvider);
          ref.invalidate(inventoryRequestsProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildRingkasanSection(summaryAsync),
            const SizedBox(height: 20),
            _buildRequestSection(requestsAsync),
            const Divider(height: 32),
            _buildShortcutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanSection(AsyncValue<InventorySummary> summaryAsync) {
    return summaryAsync.when(
      loading: () => SkeletonLoader(
        child: SkeletonBlock(height: 92, borderRadius: 20),
      ),
      error: (error, _) => _ErrorCard(
        message: 'Gagal memuat ringkasan inventory.',
        onRetry: () => ref.invalidate(inventorySummaryProvider),
      ),
      data: (summary) {
        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${summary.totalItem} jenis barang',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        if (summary.stokRendahCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${summary.stokRendahCount} di bawah minimum',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (summary.nilaiStok > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Nilai stok: ${_rupiah.format(summary.nilaiStok)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestSection(AsyncValue<List<InventoryRequest>> requestsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.input_rounded, size: 20, color: context.colors.primary),
            const SizedBox(width: 8),
            Text(
              'Request Masuk dari Workshop',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Request Pending',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
        SizedBox(height: 8),
        requestsAsync.when(
          loading: () => const SkeletonLoader(
            child: Column(
              children: [
                SkeletonBlock(height: 76, borderRadius: 14),
                SizedBox(height: 8),
                SkeletonBlock(height: 76, borderRadius: 14),
              ],
            ),
          ),
          error: (error, _) => _ErrorCard(
            message: 'Gagal memuat request sparepart.',
            onRetry: () => ref.invalidate(inventoryRequestsProvider),
          ),
          data: (requests) {
            final pending =
                requests.where((r) => r.status == InventoryRequestStatus.pending).toList();
            if (pending.isEmpty) {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 32, color: context.colors.success),
                    SizedBox(height: 8),
                    Text(
                      'Tidak ada request pending',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final request in pending)
                  QueueCard(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          context.colors.warning.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.build_rounded,
                        size: 20,
                        color: context.colors.warning,
                      ),
                    ),
                    title: '${request.platNomor} \u2022 ${request.kategoriServis}',
                    subtitle: '${request.totalItems} item diminta',
                    statusLabel: request.status.label,
                    statusColor: context.colors.warning,
                    onTap: () => context.push('/inventory/request/${request.id}'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildShortcutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 20, color: context.colors.primary),
            const SizedBox(width: 8),
            Text(
              'Menu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ShortcutTile(
                icon: Icons.warehouse_outlined,
                title: 'Cek Stok',
                onTap: () => context.push('/inventory/stok'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ShortcutTile(
                icon: Icons.fact_check_outlined,
                title: 'Stok Opname',
                onTap: () => context.push('/inventory/opname'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ShortcutTile(
                icon: Icons.history_rounded,
                title: 'Riwayat',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Riwayat akan segera hadir'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
           Icon(Icons.cloud_off_rounded, color: context.colors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: context.colors.primary, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
