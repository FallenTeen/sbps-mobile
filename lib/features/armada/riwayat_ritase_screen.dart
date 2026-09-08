import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'armada_providers.dart';
import 'models/armada.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Riwayat ritase/pengiriman milik driver (modul Armada) dengan pagination.
class RiwayatRitaseScreen extends ConsumerWidget {
  const RiwayatRitaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ritaseRiwayatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Ritase'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ritaseRiwayatProvider.notifier).refresh(),
        child: _buildList(context, ref, state),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, RitaseRiwayatState state) {
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
            onPressed: () => ref.read(ritaseRiwayatProvider.notifier).refresh(),
            child: const Text('Coba lagi'),
          ),
        ),
      ]);
    }
    if (state.items.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 160),
        Icon(Icons.route_outlined, size: 44),
        SizedBox(height: 12),
        Text('Belum ada riwayat ritase.', textAlign: TextAlign.center),
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
                    : () =>
                        ref.read(ritaseRiwayatProvider.notifier).loadMore(),
                child: Text(state.loading ? 'Memuat...' : 'Muat lagi'),
              ),
            ),
          );
        }
        return _RitaseCard(ritase: state.items[i]);
      },
    );
  }
}

class _RitaseCard extends StatelessWidget {
  const _RitaseCard({required this.ritase});

  final RitaseItem ritase;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${ritase.material ?? 'Material'} • ${_fmtTanggal(ritase.tanggal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (ritase.status != null) _RitaseBadge(status: ritase.status!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${ritase.jumlahRit ?? 0} rit'
              '${ritase.ruteAsal != null && ritase.ruteTujuan != null ? ' • ${ritase.ruteAsal} → ${ritase.ruteTujuan}' : ''}',
            ),
            if (ritase.totalUpahRit != null) ...[
              const SizedBox(height: 4),
              Text(
                'Upah: ${_fmtUang(ritase.totalUpahRit!)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RitaseBadge extends StatelessWidget {
  const _RitaseBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'disetujui' => Colors.green,
      'ditagih' => Colors.blue,
      'draft' => Colors.orange,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_labelStatus(status),
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

String _labelStatus(String status) => switch (status) {
      'disetujui' => 'Disetujui',
      'ditagih' => 'Ditagih',
      'draft' => 'Draft',
      _ => status,
    };

String _fmtTanggal(String? tanggal) {
  if (tanggal == null || tanggal.isEmpty) return '-';
  final t = DateTime.tryParse(tanggal);
  if (t == null) return tanggal;
  return '${t.day}/${t.month}/${t.year}';
}

String _fmtUang(double n) {
  final rounded = n.round();
  final s = rounded.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final remaining = s.length - 1 - i;
    if (remaining > 0 && remaining % 3 == 0) buf.write('.');
  }
  return 'Rp $buf';
}
