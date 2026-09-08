import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dashboard/dashboard_providers.dart';
import 'servis_providers.dart';

/// Screen Overview Seluruh Armada & Status Operasional untuk Manajemen (Owner, Admin Keuangan, dsb).
class OverviewArmadaScreen extends ConsumerWidget {
  const OverviewArmadaScreen({super.key});

  Color _statusColor(String? status) {
    return switch (status?.toLowerCase()) {
      'aktif' || 'beroperasi' => Colors.green,
      'standby' => Colors.blue,
      'servis' || 'perbaikan' => Colors.orange,
      'rusak' || 'nonaktif' => Colors.red,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masterArmadaAsync = ref.watch(masterArmadaProvider);
    final armadaStatusAsync = ref.watch(armadaStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview Seluruh Armada'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(masterArmadaProvider);
          ref.invalidate(armadaStatusProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status Summary Cards
            armadaStatusAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (statusData) {
                if (statusData.items.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Status (${statusData.total} Unit)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusData.items.map((item) {
                        final color = _statusColor(item.status);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.jumlah}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              Text(
                                item.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),

            Text(
              'Daftar Unit Armada',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            masterArmadaAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Center(
                child: Column(
                  children: [
                    Text('Gagal memuat data armada: $err'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(masterArmadaProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (armadaList) {
                if (armadaList.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Tidak ada unit armada terdaftar.')),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: armadaList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final armada = armadaList[index];
                    final color = _statusColor(armada.status);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.local_shipping_outlined,
                            color: color,
                          ),
                        ),
                        title: Text(
                          armada.platNomor,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            if (armada.kodeUnit != null && armada.kodeUnit!.isNotEmpty)
                              'Unit: ${armada.kodeUnit}',
                            if (armada.jenis != null && armada.jenis!.isNotEmpty)
                              armada.jenis,
                          ].join(' • '),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            armada.status ?? 'Aktif',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () {
                          // View servis riwayat / ajukan servis
                          context.push('/armada/servis');
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
