import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../shared/widgets/adaptive_master_detail.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/searchable_list_header.dart';
import 'detail_servis_screen.dart';
import 'servis_providers.dart';

/// Screen daftar riwayat pengajuan servis armada dengan search, filter status dan pagination.
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(servisRiwayatProvider);

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
        title: const Text('Riwayat Servis'),
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
          subtitle: 'Detail pengajuan & aksi persetujuan akan tampil di sini',
        ),
        masterBuilder: (context, selectedId, onSelect) => Column(
          children: [
            SearchableListHeader(
              hintText: 'Cari plat, keluhan, atau teknisi...',
              onChanged: (v) => setState(() => _searchQuery = v),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Semua'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: state.statusFilter == null,
                      onSelected: (_) {
                        ref
                            .read(servisRiwayatProvider.notifier)
                            .filterByStatus(null);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Menunggu'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: state.statusFilter == 'diajukan',
                      onSelected: (_) {
                        ref
                            .read(servisRiwayatProvider.notifier)
                            .filterByStatus('diajukan');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Disetujui'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: state.statusFilter == 'disetujui',
                      onSelected: (_) {
                        ref
                            .read(servisRiwayatProvider.notifier)
                            .filterByStatus('disetujui');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Dikerjakan'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: state.statusFilter == 'dikerjakan',
                      onSelected: (_) {
                        ref
                            .read(servisRiwayatProvider.notifier)
                            .filterByStatus('dikerjakan');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Selesai'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: state.statusFilter == 'selesai',
                      onSelected: (_) {
                        ref
                            .read(servisRiwayatProvider.notifier)
                            .filterByStatus('selesai');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Ditolak'),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      selected: state.statusFilter == 'ditolak',
                      onSelected: (_) {
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
                onRefresh: () =>
                    ref.read(servisRiwayatProvider.notifier).refresh(),
                child: _buildList(
                  context,
                  ref,
                  state,
                  items,
                  selectedId,
                  onSelect,
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

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    ServisRiwayatState state,
    List<dynamic> items,
    String? selectedId,
    void Function(String id) onSelect,
  ) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Gagal memuat data riwayat servis',
        subtitle:
            'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
        actionLabel: 'Coba lagi',
        onAction: () => ref.read(servisRiwayatProvider.notifier).refresh(),
      );
    }

    if (items.isEmpty) {
      return AppEmptyState(
        icon: _searchQuery.isNotEmpty
            ? Icons.search_off_outlined
            : Icons.build_outlined,
        title: _searchQuery.isNotEmpty
            ? 'Tidak Ada Hasil Pencarian'
            : 'Belum ada riwayat pengajuan servis',
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
          final color = _statusColor(item.status);

          return Card(
            color: item.id == selectedId
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
                : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(item.id),
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
                            _statusLabel(item.status),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
