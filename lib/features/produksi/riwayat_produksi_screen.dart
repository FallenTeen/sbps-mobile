import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/production_session.dart';
import 'produksi_providers.dart';

/// Riwayat sesi produksi milik user dengan filter tanggal & mesin,
/// pagination tombol "Muat lagi" (Fase A2.3).
class RiwayatProduksiScreen extends ConsumerWidget {
  const RiwayatProduksiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riwayatProduksiProvider);
    final filter = ref.watch(riwayatFilterProvider);
    final mesinAsync = ref.watch(mesinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Produksi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(filter.tanggal == null
                        ? 'Semua tanggal'
                        : filter.tanggal!),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(now.year - 2),
                        lastDate: now,
                      );
                      if (picked != null) {
                        ref.read(riwayatFilterProvider.notifier).set(
                              RiwayatFilter(
                                tanggal: picked.toIso8601String().substring(0, 10),
                                mesinId: filter.mesinId,
                              ),
                            );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: filter.mesinId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
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
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(riwayatProduksiProvider.notifier).refresh(),
              child: _buildList(context, ref, state, filter),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    RiwayatProduksiState state,
    RiwayatFilter filter,
  ) {
    if (state.loading && state.items.isEmpty && state.error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(state.error!, textAlign: TextAlign.center),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 160),
          Icon(Icons.inbox_outlined, size: 44),
          SizedBox(height: 12),
          Text('Belum ada riwayat untuk filter ini.', textAlign: TextAlign.center),
        ],
      );
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
                    : () => ref.read(riwayatProduksiProvider.notifier).loadMore(),
                child: Text(state.loading ? 'Memuat...' : 'Muat lagi'),
              ),
            ),
          );
        }
        return _RiwayatCard(session: state.items[i]);
      },
    );
  }
}

class _RiwayatCard extends StatelessWidget {
  const _RiwayatCard({required this.session});

  final ProductionSession session;

  @override
  Widget build(BuildContext context) {
    String jam(DateTime? t) => t == null
        ? '-'
        : '${t.day}/${t.month} '
            '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        title: Text('${session.produkNama ?? 'Produk'} — ${session.mesinNama ?? 'Mesin'}'),
        subtitle: Text(
          '${jam(session.mulai?.toLocal())} → ${jam(session.selesai?.toLocal())}\n'
          'Titik: ${session.titikNama ?? '-'}',
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_fmtNum(session.hasilOutput)} ${session.satuanOutput ?? ''}'.trim(),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(session.berjalan ? 'Berjalan' : 'Selesai',
                  style: const TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtNum(double n) =>
    n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);
