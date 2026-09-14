import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../core/formatters.dart';
import 'models/production_session.dart';
import 'produksi_providers.dart';

/// Riwayat sesi produksi milik user dengan filter tanggal & mesin,
/// pagination tombol "Muat lagi" (Fase A2.3) - Updated with uniform history (Fase 2).
class RiwayatProduksiScreen extends ConsumerStatefulWidget {
  const RiwayatProduksiScreen({super.key});

  @override
  ConsumerState<RiwayatProduksiScreen> createState() =>
      _RiwayatProduksiScreenState();
}

class _RiwayatProduksiScreenState extends ConsumerState<RiwayatProduksiScreen> {
  String? _selectedPeriod;
  String? _selectedStatus;

  final List<String> _periodOptions = const [
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
    'Semua',
  ];

  final List<String> _statusOptions = const ['Semua', 'Berjalan', 'Selesai'];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riwayatProduksiProvider);
    final filter = ref.watch(riwayatFilterProvider);
    final mesinAsync = ref.watch(mesinProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Produksi'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          // Period Filter Chips (Fase 2)
          _PeriodFilterSection(
            options: _periodOptions,
            selected: _selectedPeriod,
            onChanged: (value) {
              setState(() => _selectedPeriod = value);
              _handlePeriodChange(value, ref);
            },
          ),

          // Status Filter Chips (Fase 2)
          _StatusFilterSection(
            options: _statusOptions,
            selected: _selectedStatus,
            onChanged: (value) {
              setState(() => _selectedStatus = value);
              _handleStatusChange(value, ref);
            },
          ),

          // Machine Filter (existing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              initialValue: filter.mesinId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filter Mesin',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Semua mesin'),
              items: [
                for (final m in mesinAsync.value ?? const [])
                  DropdownMenuItem(value: m.id, child: Text(m.nama)),
              ],
              onChanged: (v) => ref
                  .read(riwayatFilterProvider.notifier)
                  .set(RiwayatFilter(tanggal: filter.tanggal, mesinId: v)),
            ),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(riwayatProduksiProvider.notifier).refresh(),
              child: _buildList(context, ref, state),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePeriodChange(String? period, WidgetRef ref) {
    final now = DateTime.now();
    String? tanggal;

    switch (period) {
      case 'Hari Ini':
        tanggal = now.toIso8601String().substring(0, 10);
        break;
      case 'Minggu Ini':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        tanggal = weekStart.toIso8601String().substring(0, 10);
        break;
      case 'Bulan Ini':
        final monthStart = DateTime(now.year, now.month, 1);
        tanggal = monthStart.toIso8601String().substring(0, 10);
        break;
      case 'Semua':
      default:
        tanggal = null;
    }

    final currentFilter = ref.read(riwayatFilterProvider);
    ref
        .read(riwayatFilterProvider.notifier)
        .set(RiwayatFilter(tanggal: tanggal, mesinId: currentFilter.mesinId));
  }

  void _handleStatusChange(String? status, WidgetRef ref) {
    // Status filtering would need backend support
    // For now, this is a UI placeholder
    // When backend T1 is ready, implement actual filtering
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    RiwayatProduksiState state,
  ) {
    if (state.loading && state.items.isEmpty && state.error == null) {
      return const SkeletonListView(itemCount: 5);
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Riwayat',
            subtitle: state.error,
            actionLabel: 'Coba Lagi',
            onAction: () =>
                ref.read(riwayatProduksiProvider.notifier).refresh(),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Belum Ada Riwayat',
            subtitle: 'Belum ada data riwayat produksi untuk filter ini.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= state.items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: FilledButton.tonal(
                onPressed: state.loading
                    ? null
                    : () =>
                          ref.read(riwayatProduksiProvider.notifier).loadMore(),
                child: Text(state.loading ? 'Memuat...' : 'Muat lagi'),
              ),
            ),
          );
        }
        return StaggeredEntrance(
          index: i,
          child: _RiwayatCard(session: state.items[i]),
        );
      },
    );
  }
}

class _PeriodFilterSection extends StatelessWidget {
  const _PeriodFilterSection({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Periode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    selected: selected == option,
                    onSelected: (bool isSelected) {
                      onChanged(isSelected ? option : null);
                    },
                    selectedColor: Colors.teal.withValues(alpha: 0.1),
                    checkmarkColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: selected == option ? Colors.teal : Colors.black87,
                      fontWeight: selected == option
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterSection extends StatelessWidget {
  const _StatusFilterSection({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(option),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -2,
                      vertical: -2,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    selected: selected == option,
                    onSelected: (bool isSelected) {
                      onChanged(isSelected ? option : null);
                    },
                    selectedColor: Colors.teal.withValues(alpha: 0.1),
                    checkmarkColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: selected == option ? Colors.teal : Colors.black87,
                      fontWeight: selected == option
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildList(
  BuildContext context,
  WidgetRef ref,
  RiwayatProduksiState state,
  RiwayatFilter filter,
) {
  if (state.loading && state.items.isEmpty && state.error == null) {
    return const SkeletonListView(itemCount: 5);
  }
  if (state.error != null && state.items.isEmpty) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal Memuat Riwayat',
          subtitle: state.error,
          actionLabel: 'Coba Lagi',
          onAction: () => ref.read(riwayatProduksiProvider.notifier).refresh(),
        ),
      ],
    );
  }
  if (state.items.isEmpty) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Belum Ada Riwayat',
          subtitle: 'Belum ada data riwayat produksi untuk filter ini.',
        ),
      ],
    );
  }

  return ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    itemCount: state.items.length + (state.hasMore ? 1 : 0),
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, i) {
      if (i >= state.items.length) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: FilledButton.tonal(
              onPressed: state.loading
                  ? null
                  : () => ref.read(riwayatProduksiProvider.notifier).loadMore(),
              child: Text(state.loading ? 'Memuat...' : 'Muat lagi'),
            ),
          ),
        );
      }
      return StaggeredEntrance(
        index: i,
        child: _RiwayatCard(session: state.items[i]),
      );
    },
  );
}

class _RiwayatCard extends StatelessWidget {
  const _RiwayatCard({required this.session});

  final ProductionSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          '${session.produkNama ?? 'Produk'} — ${session.mesinNama ?? 'Mesin'}',
        ),
        subtitle: Text(
          '${fmtTanggalWaktu(session.mulai?.toLocal())} → ${fmtTanggalWaktu(session.selesai?.toLocal())}\n'
          'Titik: ${session.titikNama ?? '-'}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${fmtNum(session.hasilOutput)} ${session.satuanOutput ?? ''}'
                  .trim(),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                session.berjalan ? 'Berjalan' : 'Selesai',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
