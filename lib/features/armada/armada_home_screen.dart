import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'armada_providers.dart';
import 'models/armada.dart';

/// Home modul Armada (role Driver Armada): menampilkan kendaraan milik
/// driver beserta pintu masuk ke Riwayat Ritase & Checklist Harian.
class ArmadaHomeScreen extends ConsumerWidget {
  const ArmadaHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Armada')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(armadaSayaProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping,
                    size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Kendaraan Saya',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._armadaSection(ref),
            const SizedBox(height: 24),
            Text('Menu',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.route_outlined),
                title: const Text('Riwayat Ritase'),
                subtitle: const Text('Pengiriman & upah per rit'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/armada/ritase'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist_rtl),
                title: const Text('Checklist Harian'),
                subtitle: const Text('Catat kondisi kendaraan hari ini'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/armada/checklist'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _armadaSection(WidgetRef ref) {
    final armada = ref.watch(armadaSayaProvider);
    return switch (armada) {
      AsyncData(value: final items) => items.isEmpty
          ? const [_EmptyArmada()]
          : [for (final a in items) _ArmadaCard(armada: a)],
      AsyncError(:final error) => [_ErrorView(message: '$error')],
      _ => const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
    };
  }
}

class _ArmadaCard extends StatelessWidget {
  const _ArmadaCard({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus_outlined,
                    size: 32, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(armada.platNomor,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                _StatusChip(status: armada.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 4,
              children: [
                if (armada.jenis != null)
                  _Info(label: 'Jenis', value: _labelJenis(armada.jenis!)),
                if (armada.kodeUnit != null)
                  _Info(label: 'Unit', value: armada.kodeUnit!),
                if (armada.titikNama != null)
                  _Info(label: 'Titik', value: armada.titikNama!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final aktif = status == 'aktif' || status == 'beroperasi';
    final color = aktif ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status ?? '-',
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _EmptyArmada extends StatelessWidget {
  const _EmptyArmada();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.no_crash_outlined, size: 44),
          SizedBox(height: 8),
          Text('Belum ada armada yang ditugaskan ke Anda.',
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

String _labelJenis(String jenis) => switch (jenis) {
      'dump_truck' => 'Dump Truck',
      'mixer_beton' => 'Mixer Beton',
      'excavator' => 'Excavator',
      'mobil_pickup' => 'Mobil Pickup',
      _ => jenis,
    };
