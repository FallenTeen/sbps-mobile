import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/adaptive_master_detail.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/searchable_list_header.dart';
import '../auth/auth_providers.dart';
import 'detail_servis_screen.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';
import 'servis_status.dart';

/// Screen daftar servis armada — berfungsi sebagai WORK QUEUE:
/// kartu berisi unit, kategori, keluhan, tanggal, pengaju, status, dan
/// next action; di atasnya ada ringkasan jumlah per status (dari server).
class RiwayatServisScreen extends ConsumerStatefulWidget {
  const RiwayatServisScreen({super.key, this.initialSelectedId});

  /// Id awal dari query `?selected=` (deep-link, mode Expanded).
  final String? initialSelectedId;

  @override
  ConsumerState<RiwayatServisScreen> createState() =>
      _RiwayatServisScreenState();
}

class _RiwayatServisScreenState extends ConsumerState<RiwayatServisScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(servisRiwayatProvider);
    final summaryAsync = ref.watch(servisQueueSummaryProvider);
    final canApprove = canApproveServis(ref.watch(activeRoleProvider));

    final q = _searchQuery.toLowerCase();
    final items = q.isEmpty
        ? state.items
        : state.items
              .where(
                (item) =>
                    (item.platNomor ?? '').toLowerCase().contains(q) ||
                    item.keluhan.toLowerCase().contains(q) ||
                    (item.kodeUnit ?? '').toLowerCase().contains(q) ||
                    (item.jenisArmada ?? '').toLowerCase().contains(q) ||
                    (item.diajukanOleh ?? '').toLowerCase().contains(q),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Servis Armada'),
        actions: [
          const PortalSwitchButton(),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Ajukan Servis Baru',
            onPressed: () => context.push('/armada/servis/ajuan'),
          ),
        ],
      ),
      body: AdaptiveMasterDetail(
        initialSelectedId: widget.initialSelectedId,
        pushRouteFor: (id) => '/armada/servis/$id',
        emptyDetailPlaceholder: const MasterDetailEmptyPlaceholder(
          icon: Icons.build_outlined,
          title: 'Pilih pengajuan servis',
          subtitle:
              'Detail pengajuan, persetujuan & timeline akan tampil di sini',
        ),
        masterBuilder: (context, selectedId, onSelect) => Column(
          children: [
            // Ringkasan work queue (jumlah per status dari server).
            _QueueSummary(
              summaryAsync: summaryAsync,
              activeFilter: state.statusFilter,
              onTapStatus: (status) {
                ref
                    .read(servisRiwayatProvider.notifier)
                    .filterByStatus(status);
              },
              onRefresh: _refreshAll,
            ),
            SearchableListHeader(
              hintText: 'Cari plat, keluhan, atau teknisi...',
              onChanged: (v) => setState(() => _searchQuery = v),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipLabel(
                      label: 'Semua',
                      selected: state.statusFilter == null,
                      onTap: () {
                        ref
                            .read(servisRiwayatProvider.notifier)
                            .filterByStatus(null);
                      },
                    ),
                    const SizedBox(width: 8),
                    for (final status in kServisStatusOrder)
                      _FilterChipLabel(
                        label: servisStatusLabel(status),
                        selected: state.statusFilter == status,
                        color: servisStatusColor(status),
                        onTap: () {
                          ref
                              .read(servisRiwayatProvider.notifier)
                              .filterByStatus(status);
                        },
                      ),
                    const SizedBox(width: 8),
                    _FilterChipLabel(
                      label: 'Ditolak',
                      selected: state.statusFilter == 'ditolak',
                      color: servisStatusColor('ditolak'),
                      onTap: () {
                        ref
                            .read(servisRiwayatProvider.notifier)
                            .filterByStatus('ditolak');
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // List Items
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                child: _buildList(
                  context,
                  ref,
                  state,
                  items,
                  selectedId,
                  onSelect,
                  canApprove,
                ),
              ),
            ),
          ],
        ),
        detailBuilder: (context, selectedId) =>
            DetailServisContent(id: selectedId),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/armada/servis/ajuan'),
        tooltip: 'Ajukan Servis Baru',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _refreshAll() async {
    // invalidate summary provider supaya angka queue ikut di-refresh.
    ref.invalidate(servisQueueSummaryProvider);
    await ref.read(servisRiwayatProvider.notifier).refresh();
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    ServisRiwayatState state,
    List<ServisArmada> items,
    String? selectedId,
    void Function(String id) onSelect,
    bool canApprove,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Gagal memuat data servis',
        subtitle:
            'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
        actionLabel: 'Coba lagi',
        onAction: _refreshAll,
      );
    }

    if (items.isEmpty) {
      return AppEmptyState(
        icon: _searchQuery.isNotEmpty
            ? Icons.search_off_outlined
            : Icons.build_outlined,
        title: _searchQuery.isNotEmpty
            ? 'Tidak Ada Hasil Pencarian'
            : 'Belum ada pengajuan servis',
        subtitle: _searchQuery.isNotEmpty
            ? 'Tidak ditemukan data yang cocok dengan "$_searchQuery".'
            : 'Ajukan servis pertama kali dengan menekan tombol + di bawah.',
        actionLabel: _searchQuery.isNotEmpty ? null : 'Ajukan Servis',
        onAction: _searchQuery.isNotEmpty
            ? null
            : () => context.push('/armada/servis/ajuan'),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(servisRiwayatProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = items[index];
          return _ServisQueueCard(
            item: item,
            isSelected: item.id == selectedId,
            canApprove: canApprove,
            onTap: () => onSelect(item.id),
          );
        },
      ),
    );
  }
}

// ── Ringkasan Work Queue ─────────────────────────────────────────────────────

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({
    required this.summaryAsync,
    required this.activeFilter,
    required this.onTapStatus,
    required this.onRefresh,
  });

  final AsyncValue<ServisQueueSummary> summaryAsync;
  final String? activeFilter;
  final void Function(String? status) onTapStatus;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: summaryAsync.when(
        loading: () => const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (error, _) => Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Ringkasan queue tidak dapat dimuat. Geser untuk coba lagi.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang ringkasan',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: onRefresh,
            ),
          ],
        ),
        data: (s) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                ('Menunggu', 'diajukan'),
                ('Disetujui', 'disetujui'),
                ('Dikerjakan', 'dikerjakan'),
                ('Selesai', 'selesai'),
                ('Ditolak', 'ditolak'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SummaryChip(
                    label: entry.$1,
                    count: s.countFor(entry.$2),
                    color: servisStatusColor(entry.$2),
                    selected: activeFilter == entry.$2,
                    onTap: () => onTapStatus(entry.$2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter Chip ─────────────────────────────────────────────────────────────

class _FilterChipLabel extends StatelessWidget {
  const _FilterChipLabel({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      selected: selected,
      selectedColor: (color ?? Colors.blue).withValues(alpha: 0.14),
      onSelected: (_) => onTap(),
    );
  }
}

// ── Kartu Work Queue ────────────────────────────────────────────────────────

class _ServisQueueCard extends StatelessWidget {
  const _ServisQueueCard({
    required this.item,
    required this.isSelected,
    required this.canApprove,
    required this.onTap,
  });

  final ServisArmada item;
  final bool isSelected;
  final bool canApprove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = servisStatusColor(item.status);

    return Card(
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      servisStatusLabel(item.status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (item.kodeUnit != null) 'Unit ${item.kodeUnit}',
                  if (item.jenisArmada != null) item.jenisArmada,
                ].join(' • '),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (item.kategori != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    formatKategoriServis(item.kategori!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                item.keluhan,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fmtTanggal(item.tanggalAjuan),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  if (item.diajukanOleh != null) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.diajukanOleh!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.status == 'ditolak'
                          ? Icons.block
                          : item.status == 'selesai'
                          ? Icons.check_circle_outline
                          : Icons.arrow_forward_rounded,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        servisNextAction(item, canApprove: canApprove),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}