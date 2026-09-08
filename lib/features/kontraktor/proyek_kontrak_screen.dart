import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'kontraktor_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Screen Portal Kontraktor: Menampilkan tab Proyek Kontrak & Invoice Klien.
class ProyekKontrakScreen extends ConsumerStatefulWidget {
  const ProyekKontrakScreen({super.key});

  @override
  ConsumerState<ProyekKontrakScreen> createState() =>
      _ProyekKontrakScreenState();
}

class _ProyekKontrakScreenState extends ConsumerState<ProyekKontrakScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'aktif' || 'berjalan' || 'lunas' => Colors.green,
      'selesai' => Colors.blue,
      'pending' || 'belum_dibayar' => Colors.orange,
      'dibatalkan' || 'jatuh_tempo' => Colors.red,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final proyeksAsync = ref.watch(proyekKontrakListProvider);
    final invoicesAsync = ref.watch(invoiceKontrakListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal Kontraktor'),
        actions: const [PortalSwitchButton()],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business_center_outlined), text: 'Proyek Kontrak'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Invoice'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: Daftar Proyek Kontrak
          RefreshIndicator(
            onRefresh: () async => ref.refresh(proyekKontrakListProvider.future),
            child: proyeksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gagal memuat proyek: $err'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(proyekKontrakListProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 140),
                      Icon(Icons.folder_open_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Belum ada proyek kontrak terdaftar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final color = _statusColor(item.status);

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/kontraktor/proyek/${item.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.nama,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                                      item.status.toUpperCase(),
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Kode: ${item.kodeProyek}${item.client != null ? ' • Klien: ${item.client}' : ''}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 13,
                                ),
                              ),
                              if (item.lokasi != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        item.lokasi!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.outline,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // TAB 2: Daftar Invoice Kontrak
          RefreshIndicator(
            onRefresh: () async => ref.refresh(invoiceKontrakListProvider.future),
            child: invoicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Gagal memuat invoice: $err'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(invoiceKontrakListProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (invoices) {
                if (invoices.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 140),
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        'Belum ada invoice kontrak.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: invoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final inv = invoices[index];
                    final color = _statusColor(inv.status);

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    inv.kodeInvoice,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
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
                                    inv.status.toUpperCase(),
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (inv.proyek != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Proyek: ${inv.proyek}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Tagihan:'),
                                Text(
                                  'Rp ${inv.total.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sisa Bayar:'),
                                Text(
                                  'Rp ${inv.sisa.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: inv.sisa > 0 ? Colors.red : Colors.green,
                                  ),
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
        ],
      ),
    );
  }
}
