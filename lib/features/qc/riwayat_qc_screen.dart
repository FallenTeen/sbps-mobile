import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'qc_providers.dart';
import 'status_badge.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../core/formatters.dart';

/// Riwayat QC: filter status, badge warna per status, pagination
/// tombol "Muat lagi" (Fase A2.5).
class RiwayatQcScreen extends ConsumerWidget {
  const RiwayatQcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qcRiwayatProvider);
    final filter = ref.watch(qcRiwayatFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat QC'),
        actions: const [PortalSwitchButton()],
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: DropdownButtonFormField<String>(
                initialValue: filter.status,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Semua status'),
                items: [
                  for (final s in kQcStatuses)
                    DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
                ],
                onChanged: (v) => ref
                    .read(qcRiwayatFilterProvider.notifier)
                    .set(QcRiwayatFilter(status: v)),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(qcRiwayatProvider.notifier).refresh(),
                child: _buildList(context, ref, state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, QcRiwayatState state) {
    if (state.loading && state.items.isEmpty && state.error == null) {
      return const SkeletonListView(itemCount: 5);
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Data QC',
            subtitle: state.error,
            actionLabel: 'Coba Lagi',
            onAction: () => ref.read(qcRiwayatProvider.notifier).refresh(),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          AppEmptyState(
            icon: Icons.science_outlined,
            title: 'Belum Ada Data QC',
            subtitle: 'Belum ada data pengujian sampel untuk filter status ini.',
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
                    : () => ref.read(qcRiwayatProvider.notifier).loadMore(),
                child: Text(state.loading ? 'Memuat...' : 'Muat lagi'),
              ),
            ),
          );
        }
        final s = state.items[i];
        return StaggeredEntrance(
          index: i,
          child: Card(
            child: ListTile(
              title: Text('${s.produkNama ?? 'Produk'} — ${s.mesinNama ?? 'Mesin'}'),
              subtitle: Text(
                'Slump ${_fmt(s.nilaiSlump)}'
                '${s.hasilUjiTekan != null ? ' • Uji tekan ${_fmt(s.hasilUjiTekan)} MPa' : ''}\n'
                '${s.titikNama ?? '-'}'
                '${s.createdAt != null ? ' • ${fmtTanggalWaktu(s.createdAt!)}' : ''}',
              ),
              isThreeLine: true,
              trailing: QcStatusBadge(status: s.status),
              onTap: () => context.push('/qc/detail', extra: s.id),
            ),
          ),
        );
      },
    );
  }
}

String _statusLabel(String status) => switch (status) {
      'menunggu_hasil' => 'Menunggu hasil',
      'lolos' => 'Lolos',
      'tidak_lolos' => 'Tidak lolos',
      _ => status,
    };

String _fmt(double? n) => n == null
    ? '-'
    : n % 1 == 0
        ? n.toInt().toString()
        : n.toStringAsFixed(1);
