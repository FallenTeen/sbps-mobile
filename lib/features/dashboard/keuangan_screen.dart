import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'dashboard_providers.dart';
import 'widgets/charts.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Dashboard finansial (HANYA Owner/Admin Keuangan — guard route +
/// validasi backend 403): chart keuangan mingguan masuk vs keluar
/// dengan pemilih periode bulan/tahun.
class KeuanganScreen extends ConsumerWidget {
  const KeuanganScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(chartPeriodProvider);
    final chart = ref.watch(keuanganChartProvider(period));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Finansial'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(keuanganChartProvider(period)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              title: 'Keuangan Mingguan',
              trailing: const PeriodPicker(),
              child: chart.when(
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SizedBox(
                  height: 180,
                  child: ErrorRetry(
                    message: e is ApiException
                        ? e.message
                        : 'Gagal memuat chart keuangan.',
                    onRetry: () =>
                        ref.invalidate(keuanganChartProvider(period)),
                  ),
                ),
                data: (data) => KeuanganBarChart(items: data.items),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
