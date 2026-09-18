import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/theme/app_theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_providers.dart';
import '../presensi/models/titik.dart';
import '../titik/titik_map_view.dart';
import '../inventory/inventory_models.dart';
import '../inventory/inventory_providers.dart';
import '../notifikasi/models/notification.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../proyek/role_permissions.dart';
import 'dashboard_providers.dart';
import 'dashboard_rules.dart';
import 'detail_titik_screen.dart';
import 'fmt.dart';
import 'models.dart';
import 'status_chip.dart' show kPoPendingLimit;
import 'widgets/charts.dart';
import '../../shared/widgets/notification_routes.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';

/// Dashboard operasional per role (Phase 15 — attention-first):
///
/// 1. Perlu Perhatian   — item actionable (servis, PO, invoice, stok kritis,
///                        produksi menunggu QC). Angka hanya tampil bila ADA
///                        drill-down; item = 0 tidak dimunculkan.
/// 2. Operasional Hari Ini — overview titik, armada, kehadiran, chart.
/// 3. Ringkasan Finansial   — chart keuangan, PO pending, invoice.
/// 4. Aktivitas Terbaru     — notifikasi terbaru (real, tap → layar terkait).
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
          if (RolePermissions.isAdminLike(role)) {
            ref.invalidate(poPendingProvider);
            ref.invalidate(invoiceBelumDibayarProvider);
            if (role == 'Owner') ref.invalidate(inventorySummaryProvider);
          }
          if (role == 'Mandor Titik') {
            ref.invalidate(produksiMenungguQcProvider);
          }
          ref.read(notificationsProvider.notifier).refresh();
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: ResponsiveCenter(
          maxWidth: AppBreakpoints.maxContentWidth,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionAttention(),
              const SizedBox(height: 20),
              const _SectionLabel(text: 'Operasional Hari Ini'),
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
                const SizedBox(height: 20),
              ],
              if (sections.showFinancial) ...[
                const _SectionLabel(text: 'Ringkasan Finansial'),
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
                const _PoPendingCard(),
                const SizedBox(height: 8),
                const _InvoiceCard(),
                const SizedBox(height: 20),
              ],
              const _SectionLabel(text: 'Aktivitas Terbaru'),
              const _SectionRecentActivity(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Judul section
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section 1: Perlu Perhatian (attention-first, actionable)
// ---------------------------------------------------------------------------

class _SectionAttention extends ConsumerWidget {
  const _SectionAttention();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);
    final admin = RolePermissions.isAdminLike(role);

    final AsyncValue<ArmadaStatusData>? armada =
        admin ? ref.watch(armadaStatusProvider) : null;
    final AsyncValue<PoPendingPage>? po =
        admin ? ref.watch(poPendingProvider) : null;
    final AsyncValue<InvoicePendingPage>? invoice =
        admin ? ref.watch(invoiceBelumDibayarProvider) : null;
    final AsyncValue<InventorySummary>? stok =
        role == 'Owner' ? ref.watch(inventorySummaryProvider) : null;
    final AsyncValue<int>? qc =
        role == 'Mandor Titik' ? ref.watch(produksiMenungguQcProvider) : null;

    final asyncs = <AsyncValue>[
      ?armada,
      ?po,
      ?invoice,
      ?stok,
      ?qc,
    ];

    final counts = AttentionCounts(
      servis: _servisCount(armada?.value),
      poPending: po?.value?.items.length ?? 0,
      invoice: invoice?.value?.items.length ?? 0,
      stokKritis: stok?.value?.stokRendahCount ?? 0,
      produksiMenungguQc: qc?.value ?? 0,
    );

    return SectionCard(
      title: 'Perlu Perhatian',
      child: asyncs.isEmpty
          ? const EmptyHint(text: 'Tidak ada yang butuh perhatian saat ini.')
          : asyncs.any((a) => a.isLoading)
          ? const CenteredProgress()
          : asyncs.any((a) => a.hasError)
          ? ErrorRetry(
              message: _firstError(asyncs),
              onRetry: () {
                ref.invalidate(armadaStatusProvider);
                ref.invalidate(poPendingProvider);
                ref.invalidate(invoiceBelumDibayarProvider);
                ref.invalidate(inventorySummaryProvider);
                ref.invalidate(produksiMenungguQcProvider);
              },
            )
          : _AttentionList(items: attentionItemsFor(role, counts)),
    );
  }

  static int _servisCount(ArmadaStatusData? d) {
    if (d == null) return 0;
    for (final item in d.items) {
      if (item.status == 'servis') return item.jumlah;
    }
    return 0;
  }

  static String _firstError(List<AsyncValue> asyncs) {
    for (final a in asyncs) {
      if (!a.hasError) continue;
      final e = a.error;
      if (e is ApiException) return e.message;
    }
    return 'Gagal memuat data dashboard.';
  }
}

class _AttentionList extends StatelessWidget {
  const _AttentionList({required this.items});

  final List<AttentionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyHint(text: 'Tidak ada yang butuh perhatian saat ini.');
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _AttentionCard(item: items[i]),
        ],
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.tone) {
      AttentionTone.critical => Theme.of(context).colorScheme.error,
      AttentionTone.warning => Colors.orange.shade800,
      AttentionTone.info => Theme.of(context).colorScheme.primary,
    };
    return Card(
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(item.icon, color: color, size: 21),
        ),
        title: Text(
          item.label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(item.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(item.route),
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
          border: Border.all(color: context.colors.border),
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
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section: Status armada (tap → overview armada, bukan dead-end)
// ---------------------------------------------------------------------------

class _SectionArmada extends ConsumerWidget {
  const _SectionArmada();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(armadaStatusProvider);

    return SectionCard(
      title: 'Status Armada',
      trailing: TextButton.icon(
        onPressed: () => context.push('/armada/overview'),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Overview'),
      ),
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
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ketuk "Overview" untuk daftar unit & status per titik.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textTertiary,
                  ),
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

// ---------------------------------------------------------------------------
// Section: Aktivitas Terbaru (notifikasi terbaru, real + drill-down)
// ---------------------------------------------------------------------------

class _SectionRecentActivity extends ConsumerWidget {
  const _SectionRecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return SectionCard(
      title: 'Aktivitas Terbaru',
      trailing: TextButton(
        onPressed: () => context.push('/notifikasi'),
        child: const Text('Lihat semua'),
      ),
      child: async.when(
        loading: () => const CenteredProgress(),
        error: (e, _) => ErrorRetry(
          message: e is ApiException ? e.message : 'Gagal memuat aktivitas.',
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const EmptyHint(text: 'Belum ada aktivitas tercatat.');
          }
          return Column(
            children: [
              for (final n in page.items.take(5)) _ActivityTile(notification: n),
            ],
          );
        },
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = !notification.isRead;
    final body = notification.body;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Semantics(
        // Status belum dibaca tidak hanya diwarnai — dibacakan ke TalkBack.
        label: unread
            ? 'Notifikasi belum dibaca'
            : 'Notifikasi sudah dibaca',
        child: CircleAvatar(
          radius: 18,
          backgroundColor:
              unread
                  ? context.colors.primary.withValues(alpha: 0.14)
                  : context.colors.surfaceVariant,
          child: Icon(
            Icons.circle_notifications_outlined,
            size: 20,
            color: unread
                ? context.colors.primary
                : context.colors.textMuted,
          ),
        ),
      ),
      title: Text(
        notification.title ?? '(Tanpa judul)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
      subtitle: body == null || body.isEmpty
          ? null
          : Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: notification.time == null
          ? null
          : Text(
              fmtRelatif(notification.time),
              style: Theme.of(context).textTheme.bodySmall,
            ),
      onTap: () => _open(context, ref),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(notificationsProvider.notifier).markRead(notification);
    if (!context.mounted) return;

    final resolved = resolveNotificationDestination(
      notification: notification,
      role: ref.read(activeRoleProvider),
    );
    if (!resolved.actionable) {
      final message = notificationDestinationMessage(resolved);
      if (message != null) {
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    try {
      context.push(resolved.route!);
    } on StateError {
      messenger.showSnackBar(
        const SnackBar(content: Text('Layar terkait belum tersedia.')),
      );
    }
  }
}