import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import 'dashboard_providers.dart';
import 'fmt.dart';
import 'status_chip.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Daftar PO menunggu approval (Owner/Admin Keuangan) — server dibatasi
/// maks 20 item terbaru; UI memberi label eksplisit bila tepat 20
/// (kemungkinan ada lebih banyak yang tidak tampil).
class PoPendingScreen extends ConsumerWidget {
  const PoPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final po = ref.watch(poPendingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PO Menunggu Approval'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(poPendingProvider.future),
        child: po.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              Icon(
                Icons.cloud_off,
                size: 44,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                e is ApiException ? e.message : 'Gagal memuat PO pending.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(poPendingProvider),
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  Icon(Icons.task_alt, size: 48, color: context.colors.success),
                  const SizedBox(height: 12),
                  const Text(
                    'Tidak ada PO yang menunggu approval.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: data.items.length + (data.cappedAtLimit ? 1 : 0) + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const InfoBanner(
                    message:
                        'Layar ini bersifat read-only — persetujuan PO '
                        'dikelola oleh tim finansial melalui sistem lain.',
                  );
                }
                final itemIndex = i - 1;
                if (itemIndex >= data.items.length) {
                  return const _CappedBanner();
                }
                final p = data.items[itemIndex];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p['kode_po']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            StatusChip(label: p['status']?.toString() ?? ''),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['supplier']?.toString() ?? '-',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${p['titik'] ?? '-'} • ${p['proyek'] ?? '-'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              fmtRp((p['total'] as num?)?.toDouble() ?? 0),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Diperlukan: ${p['tanggal_diperlukan'] ?? '-'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CappedBanner extends StatelessWidget {
  const _CappedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: context.colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Server hanya menampilkan $kPoPendingLimit PO terbaru. '
              'Bisa jadi masih ada PO lain di luar daftar ini.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
