import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/portal_switch_button.dart';
import 'servis_providers.dart';

/// Screen daftar riwayat pengajuan servis armada dengan filter status dan pagination.
class RiwayatServisScreen extends ConsumerWidget {
  const RiwayatServisScreen({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(servisRiwayatProvider);

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
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Semua'),
                  selected: state.statusFilter == null,
                  onSelected: (_) {
                    ref.read(servisRiwayatProvider.notifier).filterByStatus(null);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Menunggu'),
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
          const Divider(height: 1),

          // List Items
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(servisRiwayatProvider.notifier).refresh(),
              child: _buildList(context, ref, state),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/armada/servis/ajuan'),
        tooltip: 'Ajukan Servis Baru',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, ServisRiwayatState state) {
    if (state.loading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.read(servisRiwayatProvider.notifier).refresh(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.build_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Belum ada riwayat pengajuan servis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
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
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = state.items[index];
          final color = _statusColor(item.status);

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/armada/servis/${item.id}'),
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
                          item.tanggalAjuan,
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
