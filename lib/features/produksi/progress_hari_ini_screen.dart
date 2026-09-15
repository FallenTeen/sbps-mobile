import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import 'produksi_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Ringkasan output produksi per titik hari ini (GET /produksi/titik-progress).
class ProgressHariIniScreen extends ConsumerWidget {
  const ProgressHariIniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(titikProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Hari Ini'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(titikProgressProvider.future),
        child: progress.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 140),
              Icon(
                Icons.cloud_off,
                size: 44,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                e is ApiException ? e.message : 'Gagal memuat progress.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(titikProgressProvider),
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
                  const Icon(Icons.emoji_events_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada output tercatat ${data.tanggal}.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = data.items[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined, size: 32),
                    title: Text(item.titikNama ?? item.titikId),
                    subtitle: Text('${item.jumlahSesi} sesi selesai'),
                    trailing: Text(
                      fmtNum(item.totalOutput),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
