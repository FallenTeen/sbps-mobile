import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/searchable_list_header.dart';
import '../../core/formatters.dart';
import 'models/production_session.dart';
import 'produksi_providers.dart';
import 'produksi_rules.dart';

/// Riwayat sesi produksi milik user dengan filter tanggal, status, & mesin,
/// pagination tombol "Muat lagi" (Fase A2.3) - dibangun ulang Phase 13:
/// konten diekstrak ke [RiwayatProduksiContent] supaya bisa dipakai sebagai
/// isi tab "Riwayat" di Sesi Aktif (no redirect-only tab).
class RiwayatProduksiScreen extends StatelessWidget {
  const RiwayatProduksiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Produksi'),
        actions: const [PortalSwitchButton()],
      ),
      body: const RiwayatProduksiContent(),
    );
  }
}

/// Konten riwayat (filter + daftar) — dipakai halaman penuh dan tab.
class RiwayatProduksiContent extends ConsumerStatefulWidget {
  const RiwayatProduksiContent({super.key});

  @override
  ConsumerState<RiwayatProduksiContent> createState() =>
      _RiwayatProduksiContentState();
}

class _RiwayatProduksiContentState
    extends ConsumerState<RiwayatProduksiContent> {
  String? _selectedPeriod;
  String? _selectedStatus;
  String _searchQuery = '';

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

    final q = _searchQuery.toLowerCase();
    final searched = q.isEmpty
        ? state.items
        : state.items
              .where(
                (s) =>
                    (s.produkNama ?? '').toLowerCase().contains(q) ||
                    (s.mesinNama ?? '').toLowerCase().contains(q) ||
                    (s.titikNama ?? '').toLowerCase().contains(q),
              )
              .toList();
    // Filter status benar-benar bekerja secara client-side (Phase 13).
    final items = filterRiwayatByStatus(searched, _selectedStatus);

    return Column(
      children: [
        // Search + Period Filter Chips (Fase 2)
        SearchableListHeader(
          hintText: 'Cari produk atau mesin...',
          collapsible: false,
          onChanged: (v) => setState(() => _searchQuery = v),
          child: _PeriodFilterSection(
            options: _periodOptions,
            selected: _selectedPeriod,
            onChanged: (value) {
              setState(() => _selectedPeriod = value);
              _handlePeriodChange(value, ref);
            },
          ),
        ),

        // Status Filter Chips — aksi nyata (client-side filter).
        _StatusFilterSection(
          options: _statusOptions,
          selected: _selectedStatus,
          onChanged: (value) => setState(() => _selectedStatus = value),
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
            child: _buildList(context, ref, state, items),
          ),
        ),
      ],
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

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    RiwayatProduksiState state,
    List<dynamic> items,
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
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: _searchQuery.isNotEmpty || _selectedStatus != null
                ? Icons.filter_alt_off_outlined
                : Icons.inbox_outlined,
            title: _searchQuery.isNotEmpty
                ? 'Tidak Ada Hasil Pencarian'
                : 'Belum Ada Riwayat',
            subtitle: _searchQuery.isNotEmpty
                ? 'Tidak ditemukan data yang cocok dengan "$_searchQuery".'
                : 'Belum ada data riwayat produksi untuk filter ini.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= items.length) {
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
          child: _RiwayatCard(session: items[i]),
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

class _RiwayatCard extends StatelessWidget {
  const _RiwayatCard({required this.session});

  final ProductionSession session;

  @override
  Widget build(BuildContext context) {
    final status = sessionStatusLabel(session.status);
    final statusColor = session.berjalan
        ? context.colors.warning
        : context.colors.success;

    return Card(
      child: ListTile(
        title: Text(
          '${session.produkNama ?? 'Produk'} — ${session.mesinNama ?? 'Mesin'}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${fmtTanggalWaktu(session.mulai?.toLocal())} → '
              '${fmtTanggalWaktu(session.selesai?.toLocal())}',
            ),
            Text('Titik: ${session.titikNama ?? '-'}'),
          ],
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
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}