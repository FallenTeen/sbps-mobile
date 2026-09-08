import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/skeleton_loader.dart';
import '../dashboard_providers.dart';
import '../fmt.dart';
import '../models.dart';

/// Kartu section generik dengan judul + optional trailing control.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class CenteredProgress extends StatelessWidget {
  const CenteredProgress({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SkeletonLoader(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(width: double.infinity, height: 16),
              SizedBox(height: 8),
              SkeletonBlock(width: 200, height: 12),
              SizedBox(height: 8),
              SkeletonBlock(width: 140, height: 12),
            ],
          ),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.cloud_off,
            size: 32, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Dropdown pemilih periode (bulan + tahun) yang menulis ke
/// [chartPeriodProvider] — dipakai chart produksi & keuangan.
class PeriodPicker extends ConsumerWidget {
  const PeriodPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(chartPeriodProvider);
    final now = DateTime.now();
    final years =
        [for (var y = now.year; y >= now.year - 2; y--) y];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<int>(
          value: period.bulan,
          underline: const SizedBox.shrink(),
          items: [
            for (var i = 1; i <= 12; i++)
              DropdownMenuItem(value: i, child: Text(kBulanNama[i - 1])),
          ],
          onChanged: (b) => b == null
              ? null
              : ref.read(chartPeriodProvider.notifier).set((bulan: b, tahun: period.tahun)),
        ),
        const SizedBox(width: 4),
        DropdownButton<int>(
          value: period.tahun,
          underline: const SizedBox.shrink(),
          items: [
            for (final y in years)
              DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged: (t) => t == null
              ? null
              : ref.read(chartPeriodProvider.notifier).set((bulan: period.bulan, tahun: t)),
        ),
      ],
    );
  }
}

/// Chart bar produksi mingguan (total output per minggu).
class ProduksiBarChart extends StatelessWidget {
  const ProduksiBarChart({super.key, required this.items});

  final List<ProduksiChartPoint> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyHint(text: 'Belum ada produksi pada bulan ini.');
    }

    final maxOut = items
        .map((e) => e.totalOutput)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: maxOut <= 0 ? 1 : maxOut * 1.25,
          barTouchData: const BarTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxOut <= 0 ? 1 : maxOut / 3,
            getDrawingHorizontalLine: (v) => const FlLine(
              color: Color(0x22000000),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= items.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(fmtMingguLabel(items[i].minggu),
                        style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < items.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: items[i].totalOutput,
                    width: 18,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4)),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Chart bar keuangan mingguan: dua batang per minggu (masuk vs keluar).
class KeuanganBarChart extends StatelessWidget {
  const KeuanganBarChart({super.key, required this.items});

  final List<KeuanganChartPoint> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyHint(text: 'Belum ada transaksi pada bulan ini.');
    }

    final maxVal = items.fold<double>(0, (m, e) {
      final local = e.masuk > e.keluar ? e.masuk : e.keluar;
      return local > m ? local : m;
    });
    final hijau = Colors.green.shade400;
    final merah = Colors.red.shade400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: hijau, label: 'Masuk'),
            const SizedBox(width: 12),
            _LegendDot(color: merah, label: 'Keluar'),
            const Spacer(),
            Text(
              'Σ ${fmtRpCompact(items.fold<double>(0, (s, e) => s + e.masuk))} • '
              '-${fmtRpCompact(items.fold<double>(0, (s, e) => s + e.keluar))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: 0,
              maxY: maxVal <= 0 ? 1 : maxVal * 1.25,
              barTouchData: const BarTouchData(enabled: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal <= 0 ? 1 : maxVal / 3,
                getDrawingHorizontalLine: (v) => const FlLine(
                  color: Color(0x22000000),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= items.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(fmtMingguLabel(items[i].minggu),
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < items.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: items[i].masuk,
                        width: 12,
                        color: hijau,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                      BarChartRodData(
                        toY: items[i].keluar,
                        width: 12,
                        color: merah,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}
