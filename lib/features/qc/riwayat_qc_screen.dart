import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'qc_providers.dart';
import 'status_badge.dart';

/// Riwayat QC: filter status, badge warna per status, pagination
/// tombol "Muat lagi" (Fase A2.5).
class RiwayatQcScreen extends ConsumerWidget {
  const RiwayatQcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qcRiwayatProvider);
    final filter = ref.watch(qcRiwayatFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat QC')),
      body: Column(
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
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, QcRiwayatState state) {
    if (state.loading && state.items.isEmpty && state.error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 120),
        Text(state.error!, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton(
            onPressed: () => ref.read(qcRiwayatProvider.notifier).refresh(),
            child: const Text('Coba lagi'),
          ),
        ),
      ]);
    }
    if (state.items.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 160),
        Icon(Icons.science_outlined, size: 44),
        SizedBox(height: 12),
        Text('Belum ada data QC untuk filter ini.',
            textAlign: TextAlign.center),
      ]);
    }

    return ListView.separated(
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
        return Card(
          child: ListTile(
            title: Text('${s.produkNama ?? 'Produk'} — ${s.mesinNama ?? 'Mesin'}'),
            subtitle: Text(
              'Slump ${_fmt(s.nilaiSlump)}'
              '${s.hasilUjiTekan != null ? ' • Uji tekan ${_fmt(s.hasilUjiTekan)} MPa' : ''}\n'
              '${s.titikNama ?? '-'}'
              '${s.createdAt != null ? ' • ${_fmtTanggal(s.createdAt!)}' : ''}',
            ),
            isThreeLine: true,
            trailing: QcStatusBadge(status: s.status),
            onTap: () => context.push('/qc/detail', extra: s.id),
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

String _fmtTanggal(DateTime t) =>
    '${t.day}/${t.month} '
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';
