import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'dashboard_providers.dart';
import 'fmt.dart';
import 'models.dart';
import 'status_chip.dart' show kPoPendingLimit;
import 'widgets/charts.dart';

/// Dashboard finansial (HANYA Owner/Admin Keuangan — guard route +
/// validasi backend 403).
///
/// Sebelumnya layar ini cuma berisi 1 chart bar tanpa konteks tambahan.
/// Sekarang: (1) Ringkasan KPI (Total Masuk/Keluar/Saldo), (2) chart tren
/// mingguan (sama seperti sebelumnya), (3) rincian angka per minggu, dan
/// (4) pintasan PO Pending & Invoice Belum Dibayar langsung dari sini.
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
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(keuanganChartProvider(period));
            ref.invalidate(poPendingProvider);
            ref.invalidate(invoiceBelumDibayarProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Periode ${kBulanNama[period.bulan - 1]} ${period.tahun}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
              const SizedBox(height: 8),
              chart.when(
                loading: () => const _RingkasanSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (data) => data.items.isEmpty
                    ? const SizedBox.shrink()
                    : _RingkasanKpiRow(items: data.items),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Tren Mingguan',
                trailing: const PeriodPicker(),
                child: chart.when(
                  loading: () => const ChartSkeleton(),
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
              const SizedBox(height: 16),
              chart.maybeWhen(
                data: (data) => data.items.isEmpty
                    ? const SizedBox.shrink()
                    : _DetailMingguanCard(items: data.items),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 20),
              Text(
                'Perlu Tindak Lanjut',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const _PoPendingShortcutCard(),
              const SizedBox(height: 8),
              const _InvoiceShortcutCard(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ringkasan KPI — Total Masuk / Total Keluar / Saldo bulan berjalan
// ---------------------------------------------------------------------------

class _RingkasanSkeleton extends StatelessWidget {
  const _RingkasanSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonLoader(
    child: Row(
      children: [
        Expanded(child: SkeletonBlock(width: double.infinity, height: 66)),
        SizedBox(width: 8),
        Expanded(child: SkeletonBlock(width: double.infinity, height: 66)),
        SizedBox(width: 8),
        Expanded(child: SkeletonBlock(width: double.infinity, height: 66)),
      ],
    ),
  );
}

/// Ringkasan Total Masuk / Total Keluar / Saldo (surplus-defisit) bulan
/// berjalan, dihitung dari data chart yang sama — tanpa request tambahan.
///
/// Layout `Wrap` + `LayoutBuilder` (bukan `Row` rata 3 kolom tetap) supaya
/// aman terhadap font scaling besar & layar sempit, konsisten dengan pola
/// yang sudah dipakai di Monitoring Armada.
class _RingkasanKpiRow extends StatelessWidget {
  const _RingkasanKpiRow({required this.items});

  final List<KeuanganChartPoint> items;

  @override
  Widget build(BuildContext context) {
    final totalMasuk = items.fold<double>(0, (s, e) => s + e.masuk);
    final totalKeluar = items.fold<double>(0, (s, e) => s + e.keluar);
    final net = totalMasuk - totalKeluar;
    final colors = context.colors;
    final netColor = net >= 0 ? colors.chartPositive : colors.chartNegative;

    final cards = <({String label, String value, IconData icon, Color color})>[
      (
        label: 'Total Masuk',
        value: fmtRpCompact(totalMasuk),
        icon: Icons.south_west_rounded,
        color: colors.chartPositive,
      ),
      (
        label: 'Total Keluar',
        value: fmtRpCompact(totalKeluar),
        icon: Icons.north_east_rounded,
        color: colors.chartNegative,
      ),
      (
        label: net >= 0 ? 'Saldo (Surplus)' : 'Saldo (Defisit)',
        value: '${net >= 0 ? '+' : '-'}${fmtRpCompact(net.abs())}',
        icon: net >= 0
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        color: netColor,
      ),
    ];

    return Semantics(
      label:
          'Ringkasan keuangan bulan ini. '
          '${cards.map((c) => '${c.label}: ${c.value}').join(', ')}.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          const minItemWidth = 110.0;
          final columns = (constraints.maxWidth / minItemWidth).floor().clamp(
            1,
            cards.length,
          );
          final itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final c in cards)
                SizedBox(
                  width: itemWidth,
                  child: _KpiCard(c: c),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.c});

  final ({String label, String value, IconData icon, Color color}) c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(c.icon, size: 15, color: c.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              c.value,
              maxLines: 1,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rincian per minggu — angka pasti (bukan cuma chart)
// ---------------------------------------------------------------------------

class _DetailMingguanCard extends StatelessWidget {
  const _DetailMingguanCard({required this.items});

  final List<KeuanganChartPoint> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rincian per Minggu',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _DetailHeader(colors: colors),
            const Divider(height: 16),
            for (final e in items.reversed) _DetailRow(item: e, colors: colors),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: colors.textTertiary,
    );
    return Row(
      children: [
        Expanded(flex: 3, child: Text('Minggu', style: style)),
        Expanded(
          flex: 3,
          child: Text('Masuk', textAlign: TextAlign.right, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text('Keluar', textAlign: TextAlign.right, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text('Selisih', textAlign: TextAlign.right, style: style),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item, required this.colors});

  final KeuanganChartPoint item;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final selisih = item.masuk - item.keluar;
    final selisihColor = selisih >= 0
        ? colors.chartPositive
        : colors.chartNegative;

    Widget cell(
      String text, {
      TextAlign align = TextAlign.left,
      Color? color,
      FontWeight? weight,
    }) {
      return Expanded(
        flex: 3,
        // FittedBox: nilai Rupiah mengecil otomatis kalau tidak muat,
        // bukan dipotong "..." — angka finansial harus tetap utuh terbaca.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == TextAlign.right
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            style: TextStyle(fontSize: 12, color: color, fontWeight: weight),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          cell(fmtMingguLabel(item.minggu)),
          cell(
            fmtRpCompact(item.masuk),
            align: TextAlign.right,
            color: colors.chartPositive,
          ),
          cell(
            fmtRpCompact(item.keluar),
            align: TextAlign.right,
            color: colors.chartNegative,
          ),
          cell(
            '${selisih >= 0 ? '+' : ''}${fmtRpCompact(selisih)}',
            align: TextAlign.right,
            color: selisihColor,
            weight: FontWeight.w700,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pintasan PO Pending / Invoice Belum Dibayar
//
// Catatan: logic ini setara dengan `_PoPendingCard`/`_InvoiceCard` di
// dashboard_home_screen.dart (widget privat, tidak bisa di-import lintas
// file). Ditulis ulang lokal di sini supaya Dashboard Finansial punya akses
// langsung ke dua hal ini tanpa perlu ubah file lain. Kalau mau, ke depan
// ini bisa diekstrak jadi widget publik di widgets/charts.dart supaya tidak
// dobel — tapi untuk sekarang sengaja dibiarkan lokal biar scope perubahan
// minimal.
// ---------------------------------------------------------------------------

class _PoPendingShortcutCard extends ConsumerWidget {
  const _PoPendingShortcutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final po = ref.watch(poPendingProvider);

    return Card(
      child: po.when(
        loading: () => const ListTile(
          leading: Icon(Icons.pending_actions),
          title: Text('PO Menunggu Approval'),
          subtitle: CenteredProgress(),
        ),
        error: (e, _) => ListTile(
          leading: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('PO Menunggu Approval'),
          subtitle: Text(e is ApiException ? e.message : 'Gagal memuat.'),
          onTap: () => ref.invalidate(poPendingProvider),
        ),
        data: (data) => ListTile(
          leading: Stack(
            alignment: Alignment.topRight,
            children: [
              const Icon(Icons.pending_actions, size: 30),
              if (data.items.isNotEmpty)
                Badge(
                  label: Text('${data.items.length}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
            ],
          ),
          title: const Text('PO Menunggu Approval'),
          subtitle: Text(
            data.cappedAtLimit
                ? '${data.total}+ pending — menampilkan $kPoPendingLimit terbaru'
                : '${data.items.length} menunggu aksi',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/dashboard/keuangan/po-pending'),
        ),
      ),
    );
  }
}

class _InvoiceShortcutCard extends ConsumerWidget {
  const _InvoiceShortcutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(invoiceBelumDibayarProvider);

    return Card(
      child: inv.when(
        loading: () => const ListTile(
          leading: Icon(Icons.receipt_long),
          title: Text('Invoice Belum Dibayar'),
          subtitle: CenteredProgress(),
        ),
        error: (e, _) => ListTile(
          leading: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Invoice Belum Dibayar'),
          subtitle: Text(e is ApiException ? e.message : 'Gagal memuat.'),
          onTap: () => ref.invalidate(invoiceBelumDibayarProvider),
        ),
        data: (data) => ListTile(
          leading: Stack(
            alignment: Alignment.topRight,
            children: [
              const Icon(Icons.receipt_long, size: 30),
              if (data.items.isNotEmpty)
                Badge(
                  label: Text('${data.items.length}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
            ],
          ),
          title: const Text('Invoice Belum Dibayar'),
          subtitle: Text(
            data.cappedAtLimit
                ? '${data.total}+ invoice — menampilkan 20 terbaru'
                : '${data.items.length} belum lunas',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/dashboard/keuangan/invoice'),
        ),
      ),
    );
  }
}
