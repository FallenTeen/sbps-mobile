import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/api_client.dart';
import '../../core/armada_jenis.dart';
import 'dashboard_providers.dart';
import 'fmt.dart';
import 'models.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Detail satu titik kerja (Fase A2.6): koordinat, ringkasan SDM &
/// armada aktif, RAB titik (jika role berhak), dan riwayat produksi
/// hari ini.
class DetailTitikScreen extends ConsumerWidget {
  const DetailTitikScreen({super.key, required this.titikId, this.nama});

  final String titikId;

  /// Nama titik dari extra (agar AppBar langsung berjudul sebelum fetch).
  final String? nama;

  static String routePath(String titikId) => '/dashboard/titik/$titikId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(titikDetailProvider(titikId));

    return Scaffold(
      appBar: AppBar(
        title: BreadcrumbTitle(
          parentLabel: 'Dashboard',
          title: nama ?? 'Detail Titik',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(titikDetailProvider(titikId).future),
          child: detail.when(
            loading: () => const SkeletonDetailView(),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Gagal Memuat Detail Titik',
                  subtitle: e is ApiException
                      ? e.message
                      : 'Gagal memuat detail titik.',
                  actionLabel: 'Coba Lagi',
                  onAction: () => ref.invalidate(titikDetailProvider(titikId)),
                ),
              ],
            ),
            data: (d) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                StaggeredEntrance(
                  index: 0,
                  child: _Card(
                    title: d.titikNama,
                    subtitle: '${d.proyek} • status ${d.status}',
                    rows: [
                      if (d.latitude != null && d.longitude != null)
                        (
                          'Koordinat',
                          '${d.latitude!.toStringAsFixed(5)}, ${d.longitude!.toStringAsFixed(5)}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 1,
                  child: _Card(
                    title: 'Produksi Hari Ini',
                    rows: [
                      ('Total output', fmtNum(d.produksiHariIni.totalOutput)),
                      ('Jumlah sesi', '${d.produksiHariIni.jumlahSesi}'),
                    ],
                  ),
                ),
                if (d.rab != null) ...[
                  const SizedBox(height: 12),
                  StaggeredEntrance(
                    index: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Builder(
                          builder: (context) {
                            final rab = d.rab!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'RAB',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: (rab.persentase / 100).clamp(0.0, 1.0),
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                const SizedBox(height: 8),
                                _Row(
                                  'Realisasi',
                                  '${fmtRp(rab.totalRealisasi)} dari ${fmtRp(rab.totalRencana)}',
                                ),
                                _Row(
                                  'Persentase',
                                  '${fmtNum(rab.persentase)}%',
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 3,
                  child: _ListCard<SdmItem>(
                    title: 'SDM (${d.sdm.length})',
                    items: d.sdm,
                    emptyText: 'Belum ada karyawan terhubung.',
                    tileOf: (s) => ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(s.nama),
                      subtitle: s.jabatan == null ? null : Text(s.jabatan!),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 4,
                  child: _ListCard<ArmadaItem>(
                    title: 'Armada (${d.armada.length})',
                    items: d.armada,
                    emptyText: 'Belum ada armada ditugaskan.',
                    tileOf: (a) => ListTile(
                      leading: const Icon(Icons.local_shipping_outlined),
                      title: Text(a.kodeUnit),
                      subtitle: Text(
                        '${a.platNomor ?? '-'} • ${_jenisLabel(a.jenis)} • ${a.status ?? '-'}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 5,
                  child: _ListCard<PresensiRow>(
                    title: 'Presensi Hari Ini (${d.presensiHariIni.length})',
                    items: d.presensiHariIni,
                    emptyText: 'Belum ada presensi di titik ini.',
                    tileOf: (p) => ListTile(
                      leading: const Icon(Icons.fact_check_outlined),
                      title: Text(p.nama),
                      subtitle: Text(
                        'Masuk ${_jam(p.checkIn)}'
                        '${p.checkOut != null ? ' • Keluar ${_jam(p.checkOut)}' : ''}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _jenisLabel(String? jenis) => labelJenisArmada(jenis);

  static String _jam(DateTime? t) {
    if (t == null) return '-';
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, this.subtitle, this.rows = const []});

  final String title;
  final String? subtitle;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final (label, value) in rows) _Row(label, value),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(flex: 6, child: Text(value)),
      ],
    ),
  );
}

class _ListCard<T> extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.tileOf,
  });

  final String title;
  final List<T> items;
  final String emptyText;
  final Widget Function(T item) tileOf;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(emptyText)),
                  ],
                ),
              )
            else
              ...items.map(tileOf),
          ],
        ),
      ),
    );
  }
}
