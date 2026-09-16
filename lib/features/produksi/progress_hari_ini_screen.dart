import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import 'models/production_session.dart';
import 'produksi_providers.dart';
import 'produksi_rules.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Ringkasan output produksi per titik hari ini (GET /produksi/titik-progress).
class ProgressHariIniScreen extends StatelessWidget {
  const ProgressHariIniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Hari Ini'),
        actions: const [PortalSwitchButton()],
      ),
      body: const ProgressHariIniContent(),
    );
  }
}

/// Konten progress per titik — dipakai mandiri (halaman penuh) maupun
/// sebagai isi tab "Progress" di [sesi_aktif_screen.dart] (Phase 13:
/// tab tidak boleh hanya redirect ke halaman lain).
class ProgressHariIniContent extends ConsumerWidget {
  const ProgressHariIniContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(titikProgressProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(titikProgressProvider.future),
      child: progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                AppEmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: 'Belum ada output hari ini',
                  subtitle: '${data.tanggal} — mulai sesi dan catat hasil '
                      'output untuk melihat progress per titik.',
                  actionLabel: 'Muat Ulang',
                  onAction: () =>
                      ref.invalidate(titikProgressProvider),
                ),
              ],
            );
          }

          final summary = produksiHomeSummary(progress: data.items);
          final totalPoint = data.items.length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _ProgressTotalHeader(
                tanggal: data.tanggal,
                totalOutput: summary.totalOutput,
                totalSesi: summary.totalSesi,
                totalPoint: totalPoint,
              ),
              const SizedBox(height: 8),
              const Text(
                'Per Titik',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < data.items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _ProgressTile(item: data.items[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProgressTotalHeader extends StatelessWidget {
  const _ProgressTotalHeader({
    required this.tanggal,
    required this.totalOutput,
    required this.totalSesi,
    required this.totalPoint,
  });

  final String tanggal;
  final double totalOutput;
  final int totalSesi;
  final int totalPoint;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress ${tanggal.isNotEmpty ? tanggal : ''}'.trim(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Icon(
                  Icons.bar_chart,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Total Output',
                    value: fmtNum(totalOutput),
                    unit: '',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Sesi Selesai',
                    value: '$totalSesi',
                    unit: 'sesi',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Titik Produktif',
                    value: '$totalPoint',
                    unit: 'titik',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit});

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value${unit.isEmpty ? '' : ' $unit'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.item});

  final TitikProgressItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.location_on_outlined,
            size: 22,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(item.titikNama ?? item.titikId),
        subtitle: Text('${item.jumlahSesi} sesi selesai'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              fmtNum(item.totalOutput),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('output', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}