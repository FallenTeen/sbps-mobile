import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'tracking_providers.dart';

/// Jejak lokasi satu user hari ini (GET /tracking/hari-ini/{userId}).
/// Saat ini berbentuk daftar kronologis; tampilan peta/polyline menyusul
/// setelah pustaka peta ditentukan.
class TrailScreen extends ConsumerWidget {
  const TrailScreen({super.key, required this.userId, this.nama});

  final String userId;
  final String? nama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trail = ref.watch(trailProvider(userId));

    return Scaffold(
      appBar: AppBar(title: Text(nama == null ? 'Tracking Hari Ini' : nama!)),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(trailProvider(userId).future),
        child: trail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 140),
              Icon(Icons.cloud_off,
                  size: 44, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                // 403 dan 422 punya pesan berbeda dari backend — tampilkan
                // persis agar admin paham penyebabnya.
                e is ApiException ? e.message : 'Gagal memuat jejak lokasi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(trailProvider(userId)),
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
                  const Icon(Icons.route_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada titik lokasi ${data.tanggal ?? 'hari ini'}.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            final first = data.items.first.timestamp.toLocal();
            final last = data.items.last.timestamp.toLocal();
            String hhmm(DateTime t) =>
                '${t.hour.toString().padLeft(2, '0')}:'
                '${t.minute.toString().padLeft(2, '0')}';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${data.tanggal ?? ''} • ${data.items.length} titik',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Rentang: ${hhmm(first)} → ${hhmm(last)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (final p in data.items.reversed)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(hhmm(p.timestamp.toLocal())),
                    subtitle: Text(
                        '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
