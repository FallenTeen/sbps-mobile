import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/adaptive_grid.dart';
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
        actions: [PortalSwitchButton()],
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
            _buildPerhatianHariIni(summaryAsync, requestsAsync),
            const SizedBox(height: 20),
            _buildRequestSection(requestsAsync),
            const Divider(height: 32),
            _buildShortcutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPerhatianHariIni(
    AsyncValue<InventorySummary> summaryAsync,
    AsyncValue<List<InventoryRequest>> requestsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.priority_high_rounded,
              size: 20,
              color: context.colors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Perhatian Hari Ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        summaryAsync.when(
          loading: () => const SkeletonLoader(
            child: Column(
              children: [
                SkeletonBlock(height: 80, borderRadius: 14),
                SizedBox(height: 8),
                SkeletonBlock(height: 80, borderRadius: 14),
              ],
            ),
          ),
          error: (error, _) => _ErrorCard(
            message: 'Gagal memuat ringkasan.',
            onRetry: () => ref.invalidate(inventorySummaryProvider),
          ),
          data: (summary) {
            final pendingCount = summary.requestPendingCount;
            final pendingRequests = requestsAsync.value ?? [];
            final firstPendingId = pendingRequests
                .where((r) => r.status == InventoryRequestStatus.pending)
                .firstOrNull
                ?.id;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AttentionTile(
                        icon: Icons.warning_amber_rounded,
                        count: summary.stokRendahCount,
                        label: 'Stok Rendah',
                        color: context.colors.error,
                        onTap: () => context.push('/inventory/stok?rendah=1'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AttentionTile(
                        icon: Icons.input_rounded,
                        count: pendingCount,
                        label: 'Request',
                        color: context.colors.warning,
                        onTap: firstPendingId != null
                            ? () => context.push(
                                '/inventory/request/$firstPendingId',
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _AttentionTile(
                  icon: Icons.fact_check_outlined,
                  label: 'Stok Opname',
                  subtitle: 'Hitung fisik stok',
                  color: context.colors.info,
                  onTap: () => context.push('/inventory/opname'),
                ),
                if (summary.nilaiStok > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: context.colors.textTertiary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Nilai stok: ${_rupiah.format(summary.nilaiStok)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRequestSection(
    AsyncValue<List<InventoryRequest>> requestsAsync,
  ) {
    return requestsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (requests) {
        final pending = requests
            .where((r) => r.status == InventoryRequestStatus.pending)
            .toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.input_rounded,
                  size: 20,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Request dari Workshop',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${pending.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final request in pending)
              QueueCard(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: context.colors.warning.withValues(
                    alpha: 0.12,
                  ),
                  child: Icon(
                    Icons.build_rounded,
                    size: 20,
                    color: context.colors.warning,
                  ),
                ),
                title:
                    '${request.platNomor} \u2022 ${request.kategoriServis}',
                subtitle: '${request.totalItems} item diminta',
                statusLabel: request.status.label,
                statusColor: context.colors.warning,
                onTap: () =>
                    context.push('/inventory/request/${request.id}'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildShortcutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              size: 20,
              color: context.colors.primary,
            ),
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
        AdaptiveGrid(
          compactColumns: 2,
          mediumColumns: 2,
          expandedColumns: 4,
          spacing: 10,
          children: [
            _ShortcutTile(
              icon: Icons.warehouse_outlined,
              title: 'Daftar Stok',
              onTap: () => context.push('/inventory/stok'),
            ),
            _ShortcutTile(
              icon: Icons.fact_check_outlined,
              title: 'Stok Opname',
              onTap: () => context.push('/inventory/opname'),
            ),
            _ShortcutTile(
              icon: Icons.history_rounded,
              title: 'Riwayat Mutasi',
              onTap: () => context.push('/inventory/riwayat'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.icon,
    required this.label,
    required this.color,
    this.count,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int? count;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasCount = count != null;
    final isZero = hasCount && count == 0;
    final accentColor = isZero ? context.colors.success : color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: onTap != null
                  ? accentColor.withValues(alpha: 0.2)
                  : context.colors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textTertiary,
                        ),
                      )
                    else if (hasCount)
                      Text(
                        isZero ? 'Aman' : '$count',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: accentColor.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: context.colors.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
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
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: context.colors.primary,
                    size: 22,
                  ),
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
