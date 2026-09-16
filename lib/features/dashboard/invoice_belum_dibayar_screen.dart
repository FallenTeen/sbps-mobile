import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import 'dashboard_providers.dart';
import 'fmt.dart';
import 'status_chip.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Daftar invoice belum lunas (Owner/Admin Keuangan) — server dibatasi
/// maks 20 item terbaru; label eksplisit bila tepat 20.
class InvoiceBelumDibayarScreen extends ConsumerWidget {
  const InvoiceBelumDibayarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(invoiceBelumDibayarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Belum Dibayar'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(invoiceBelumDibayarProvider.future),
        child: inv.when(
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
                e is ApiException ? e.message : 'Gagal memuat invoice.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(invoiceBelumDibayarProvider),
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
                    'Semua invoice sudah lunas.',
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
                        'Layar ini bersifat read-only — pembayaran invoice '
                        'dikelola oleh tim finansial melalui sistem lain.',
                  );
                }
                final itemIndex = i - 1;
                if (itemIndex >= data.items.length) {
                  return const _CappedBanner();
                }
                final v = data.items[itemIndex];
                final sisa = (v['sisa'] as num?)?.toDouble() ?? 0;
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
                                v['kode_invoice']?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            StatusChip(label: v['status']?.toString() ?? ''),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v['unit_bisnis']?.toString() ?? '-',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          v['proyek']?.toString() ?? '-',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sisa',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  fmtRp(sisa),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: sisa > 0
                                        ? Theme.of(context).colorScheme.error
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Jatuh tempo: '
                              '${v['tanggal_jatuh_tempo'] ?? '-'}',
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
              'Server hanya menampilkan 20 invoice terbaru. '
              'Bisa jadi masih ada invoice lain di luar daftar ini.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
