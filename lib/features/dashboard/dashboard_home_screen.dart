import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_providers.dart';
import '../presensi/models/titik.dart';
import '../titik/titik_map_view.dart';
import 'dashboard_providers.dart';
import 'detail_titik_screen.dart';
import 'fmt.dart';
import 'models.dart';
import 'status_chip.dart' show kPoPendingLimit;
import 'widgets/charts.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';

/// Dashboard operasional per role (Fase A2.6):
/// - Owner/Admin Keuangan: overview + armada + kehadiran divisi +
///   chart produksi + shortcut finansial.
/// - Mandor Titik: overview + armada status (non-finansial).
/// - Kontraktor: overview non-finansial saja.
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);
    final sections = dashboardSectionsFor(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Operasional'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overviewProvider);
          if (sections.showArmadaStatus) ref.invalidate(armadaStatusProvider);
          if (sections.showKehadiran) ref.invalidate(kehadiranDivisiProvider);
          if (sections.showChartProduksi) {
            ref.invalidate(produksiChartProvider);
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: ResponsiveCenter(
          maxWidth: AppBreakpoints.maxContentWidth,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (sections.showOverview) ...[
                const _SectionOverview(),
                const SizedBox(height: 20),
              ],
              if (sections.showArmadaStatus) ...[
                const _SectionArmada(),
                const SizedBox(height: 20),
              ],
              if (sections.showKehadiran) ...[
                const _SectionKehadiran(),
                const SizedBox(height: 20),
              ],
              if (sections.showChartProduksi) ...[
                const _SectionChartProduksi(),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Dashboard Finansial'),
                    subtitle: const Text(
                      'Chart keuangan mingguan, PO & invoice',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/dashboard/keuangan'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (sections.showFinancial) ...[
                const _PoPendingCard(),
                const SizedBox(height: 8),
                const _InvoiceCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Overview titik
// ---------------------------------------------------------------------------

class _SectionOverview extends StatefulWidget {
  const _SectionOverview();

  @override
  State<_SectionOverview> createState() => _SectionOverviewState();
}

class _SectionOverviewState extends State<_SectionOverview> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final overview = ref.watch(overviewProvider);

        return SectionCard(
          title: 'Ringkasan Titik Hari Ini',
          trailing: IconButton(
            tooltip: _showMap ? 'Tampilkan Daftar' : 'Tampilkan Peta',
            icon: Icon(
              _showMap ? Icons.format_list_bulleted : Icons.map_outlined,
            ),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
          child: overview.when(
            loading: () => const CenteredProgress(),
            error: (e, _) => ErrorRetry(
              message: e is ApiException ? e.message : 'Gagal memuat overview.',
              onRetry: () => ref.invalidate(overviewProvider),
            ),
            data: (data) {
              if (data.items.isEmpty) {
                return const EmptyHint(text: 'Belum ada titik aktif hari ini.');
              }

              if (_showMap) {
                final titikList = data.items
                    .map(
                      (t) => Titik(
                        id: t.titikId,
                        nama: t.titik,
                        proyek: t.proyek,
                        latitude: t.latitude ?? 0,
                        longitude: t.longitude ?? 0,
                        radiusPresensiMeter: 0,
                        status: 'aktif',
                      ),
                    )
                    .toList();

                return TitikMapView(
                  titikList: titikList,
                  height: 280,
                  emptyMessage: 'Belum ada titik dengan koordinat valid.',
                  onDetail: (titik) => context.push(
                    DetailTitikScreen.routePath(titik.id),
                    extra: titik.nama,
                  ),
                );
              }

              return Column(
                children: [
                  for (final t in data.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TitikOverviewTile(titik: t),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Tile ringkasan satu titik — dipakai di dashboard home; tap membuka
/// detail titik.
class TitikOverviewTile extends StatelessWidget {
  const TitikOverviewTile({super.key, required this.titik});

  final TitikOverview titik;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.push(
        DetailTitikScreen.routePath(titik.titikId),
        extra: titik.titik,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titik.titik,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.colors.textTertiary,
                ),
              ],
            ),
            Text(titik.proyek, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniChip(icon: Icons.people, label: '${titik.sdmCount} SDM'),
                _MiniChip(
                  icon: Icons.local_shipping,
                  label: '${titik.armadaCount} armada',
                ),
                _MiniChip(
                  icon: Icons.fact_check,
                  label: '${titik.presensiToday} hadir',
                ),
                _MiniChip(
                  icon: Icons.precision_manufacturing,
                  label: '${fmtNum(titik.produksiToday)} output',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Status armada
// ---------------------------------------------------------------------------

class _SectionArmada extends ConsumerWidget {
  const _SectionArmada();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(armadaStatusProvider);

    return SectionCard(
      title: 'Status Armada',
      child: status.when(
        loading: () => const CenteredProgress(),
        error: (e, _) => ErrorRetry(
          message: e is ApiException ? e.message : 'Gagal memuat armada.',
          onRetry: () => ref.invalidate(armadaStatusProvider),
        ),
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyHint(text: 'Belum ada data armada.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in data.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(
                          _labelArmada(item.status),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: data.total == 0 ? 0 : item.jumlah / data.total,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.jumlah}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _labelArmada(String s) => switch (s) {
    'aktif' => 'Aktif',
    'servis' => 'Servis',
    'idle' => 'Idle',
    _ => s,
  };
}

// ---------------------------------------------------------------------------
// Section: Kehadiran divisi (Owner/Admin)
// ---------------------------------------------------------------------------

class _SectionKehadiran extends ConsumerWidget {
  const _SectionKehadiran();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(kehadiranDivisiProvider);

    return SectionCard(
      title: 'Kehadiran Divisi Hari Ini',
      child: data.when(
        loading: () => const CenteredProgress(),
        error: (e, _) => ErrorRetry(
          message: e is ApiException ? e.message : 'Gagal memuat kehadiran.',
          onRetry: () => ref.invalidate(kehadiranDivisiProvider),
        ),
        data: (d) {
          if (d.items.isEmpty) {
            return const EmptyHint(text: 'Belum ada presensi hari ini.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Total hadir: ${d.totalHadir}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final item in d.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.divisi)),
                      Text(
                        '${item.checkOut}/${item.hadir} check-out',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Chart produksi mingguan (Owner/Admin)
// ---------------------------------------------------------------------------

class _SectionChartProduksi extends ConsumerWidget {
  const _SectionChartProduksi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(chartPeriodProvider);
    final chart = ref.watch(produksiChartProvider(period));

    return SectionCard(
      title: 'Produksi Mingguan',
      trailing: PeriodPicker(),
      child: chart.when(
        loading: () => const ChartSkeleton(height: 160),
        error: (e, _) => SizedBox(
          height: 160,
          child: ErrorRetry(
            message: e is ApiException
                ? e.message
                : 'Gagal memuat chart produksi.',
            onRetry: () => ref.invalidate(produksiChartProvider(period)),
          ),
        ),
        data: (data) => ProduksiBarChart(items: data.items),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu notifikasi PO pending / invoice belum dibayar (Owner/Admin Keuangan)
// ---------------------------------------------------------------------------

class _PoPendingCard extends ConsumerWidget {
  const _PoPendingCard();

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

class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard();

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
