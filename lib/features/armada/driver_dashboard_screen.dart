import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/skeleton_loader.dart';
import 'armada_providers.dart';
import 'models/armada.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Dashboard pribadi driver: ringkasan kinerja hari ini, riwayat ritase
/// terakhir, status checklist, dan shortcut aksi.
class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armadaAsync = ref.watch(armadaSayaProvider);
    final ritaseAsync = ref.watch(ritaseRiwayatProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Saya'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(armadaSayaProvider);
          ref.invalidate(checklistHariIniProvider);
          await ref.read(ritaseRiwayatProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _VehicleSection(armadaAsync: armadaAsync),
            const SizedBox(height: 16),
            _TodaySummarySection(ritaseAsync: ritaseAsync),
            const SizedBox(height: 16),
            _ChecklistSection(checklistAsync: checklistAsync),
            const SizedBox(height: 16),
            _RecentRitaseSection(ritaseAsync: ritaseAsync),
          ],
        ),
      ),
    );
  }
}

/// Section: Info kendaraan yang dipegang driver.
class _VehicleSection extends StatelessWidget {
  const _VehicleSection({required this.armadaAsync});

  final AsyncValue<List<ArmadaSaya>> armadaAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return armadaAsync.when(
      loading: () => const SkeletonCard(),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Gagal memuat kendaraan: $e',
              style: TextStyle(color: theme.colorScheme.error)),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  const Text('Belum ada kendaraan yang ditugaskan',
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kendaraan Saya',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final a in items) _VehicleCard(armada: a),
          ],
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aktif = armada.status == 'aktif' || armada.status == 'beroperasi';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: aktif
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.local_shipping,
                    color: aktif ? Colors.green : Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        armada.platNomor,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      if (armada.kodeUnit != null)
                        Text(armada.kodeUnit!,
                            style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _StatusChip(status: armada.status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (armada.jenis != null)
                  _InfoChip(
                      icon: Icons.category_outlined,
                      label: _labelJenis(armada.jenis!)),
                if (armada.tahun != null)
                  _InfoChip(icon: Icons.calendar_today, label: '${armada.tahun}'),
                if (armada.titikNama != null)
                  _InfoChip(icon: Icons.place_outlined, label: armada.titikNama!),
                if (armada.kapasitas != null)
                  _InfoChip(icon: Icons.scale, label: armada.kapasitas!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Section: Ringkasan ritase hari ini.
class _TodaySummarySection extends StatelessWidget {
  const _TodaySummarySection({required this.ritaseAsync});

  final RitaseRiwayatState ritaseAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Ringkasan Hari Ini',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(),
            Builder(
              builder: (context) {
                if (ritaseAsync.loading && ritaseAsync.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (ritaseAsync.error != null && ritaseAsync.items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Gagal memuat data',
                        style: TextStyle(color: theme.colorScheme.error)),
                  );
                }

                final todayItems = ritaseAsync.items
                    .where((r) => r.tanggal != null && r.tanggal!.startsWith(today))
                    .toList();

                final totalRit = todayItems.length;
                final totalUpah = todayItems.fold<double>(
                    0, (sum, r) => sum + (r.totalUpahRit ?? 0));

                return Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.route,
                        label: 'Total Rit',
                        value: '$totalRit',
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryTile(
                        icon: Icons.payments_outlined,
                        label: 'Total Upah',
                        value: _formatRupiah(totalUpah),
                        color: Colors.green,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Section: Status checklist hari ini.
class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.checklistAsync});

  final AsyncValue<List<ArmadaChecklist>> checklistAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Checklist Hari Ini',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(),
            checklistAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Gagal memuat checklist',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Tidak ada kendaraan untuk checklist'),
                  );
                }

                return Column(
                  children: [
                    for (final c in items)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          c.sudahIsi
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: c.sudahIsi ? Colors.green : theme.colorScheme.outline,
                        ),
                        title: Text(c.platNomor),
                        subtitle: Text(
                          c.sudahIsi
                              ? 'Sudah diisi${c.odoKm != null ? ' • ODO: ${c.odoKm!.toStringAsFixed(0)} km' : ''}'
                              : 'Belum diisi',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/armada/checklist'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Section: Riwayat ritase terakhir (max 5).
class _RecentRitaseSection extends StatelessWidget {
  const _RecentRitaseSection({required this.ritaseAsync});

  final RitaseRiwayatState ritaseAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Riwayat Ritase Terakhir',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => context.push('/armada/ritase'),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const Divider(),
            Builder(
              builder: (context) {
                if (ritaseAsync.loading && ritaseAsync.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (ritaseAsync.error != null && ritaseAsync.items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Gagal memuat riwayat',
                        style: TextStyle(color: theme.colorScheme.error)),
                  );
                }

                if (ritaseAsync.items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Belum ada riwayat ritase'),
                  );
                }

                final recent = ritaseAsync.items.take(5).toList();

                return Column(
                  children: [
                    for (final r in recent)
                      _RitaseTile(ritase: r),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RitaseTile extends StatelessWidget {
  const _RitaseTile({required this.ritase});

  final RitaseItem ritase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ritase.material ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _RitaseStatusBadge(status: ritase.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (ritase.ruteAsal != null && ritase.ruteTujuan != null)
                  Expanded(
                    child: Text(
                      '${ritase.ruteAsal} → ${ritase.ruteTujuan}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (ritase.totalUpahRit != null)
                  Text(
                    _formatRupiah(ritase.totalUpahRit!),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
              ],
            ),
            if (ritase.tanggal != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(ritase.tanggal!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}

class _RitaseStatusBadge extends StatelessWidget {
  const _RitaseStatusBadge({this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'disetujui' => Colors.green,
      'draft' => Colors.orange,
      'ditagih' => Colors.blue,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status ?? '-',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
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

String _formatRupiah(double amount) {
  if (amount >= 1000000) {
    return 'Rp${(amount / 1000000).toStringAsFixed(1)}jt';
  }
  if (amount >= 1000) {
    return 'Rp${(amount / 1000).toStringAsFixed(0)}rb';
  }
  return 'Rp${amount.toStringAsFixed(0)}';
}
