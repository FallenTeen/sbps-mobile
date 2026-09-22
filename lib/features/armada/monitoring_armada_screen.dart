import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/armada_jenis.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../dashboard/dashboard_providers.dart';
import '../dashboard/models.dart';
import 'armada_monitoring.dart';
import 'models/servis_armada.dart';
import 'unit_monitoring_screen.dart';

/// Monitoring Armada (Bagian 21.11) — metrik utilisasi (total jam aktif,
/// HM/Jam, rekap durasi per tanggal) + kondisi seluruh armada (checklist,
/// downtime, servis) untuk menu Ketua Divisi Armada.
class MonitoringArmadaScreen extends ConsumerStatefulWidget {
  const MonitoringArmadaScreen({super.key});

  @override
  ConsumerState<MonitoringArmadaScreen> createState() =>
      _MonitoringArmadaScreenState();
}

class _MonitoringArmadaScreenState
    extends ConsumerState<MonitoringArmadaScreen> {
  ArmadaMonitoringFilter get _defaultFilter =>
      const (unitBisnisId: null, dari: null, sampai: null);

  ArmadaMonitoringFilter _filter = const (
    unitBisnisId: null,
    dari: null,
    sampai: null,
  );

  /// Filter status unit (null = semua) — diterapkan client-side.
  String? _statusFilter;

  static String _iso(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  void _setRange(int days) {
    final now = DateTime.now();
    setState(() {
      _filter = days == 30
          ? _defaultFilter
          : (
              unitBisnisId: null,
              dari: _iso(now.subtract(Duration(days: days - 1))),
              sampai: _iso(now),
            );
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(armadaMonitoringProvider(_filter));
  }

  /// Drill-down ke data satu unit — konsisten dengan Overview Armada
  /// (checklist, ODO/HM, peringatan, riwayat servis).
  void _openUnit(ArmadaMonitoringUnit unit) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnitMonitoringScreen(unit: _toMasterArmada(unit)),
      ),
    );
  }

  /// Endpoint monitoring tidak membawa titik/ODO/HM terkini; [MasterArmada]
  /// hanya perlu identitas unit — sisanya diambil ulang dari `/armada/saya`,
  /// `/armada/checklist-hari-ini`, dan `/servis-armada` di layar drill-down.
  MasterArmada _toMasterArmada(ArmadaMonitoringUnit u) => MasterArmada(
    id: u.id,
    platNomor: u.platNomor ?? u.kodeUnit ?? 'Unit ${u.id}',
    kodeUnit: u.kodeUnit,
    jenis: u.jenis,
    status: u.status,
    tipeUnit: u.tipeUnit,
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(armadaMonitoringProvider(_filter));
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Armada'),
        actions: const [PortalSwitchButton()],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      const Text('Gagal memuat monitoring armada.'),
                      const SizedBox(height: 4),
                      Text(
                        friendlyErrorMessage(err),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            data: (data) {
              if (data.perUnit.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'Tidak ada armada',
                  subtitle: 'Belum ada unit armada terdaftar untuk dimonitor.',
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _RangeSelector(
                    filter: _filter,
                    tanggalDari: data.tanggalDari,
                    tanggalSampai: data.tanggalSampai,
                    onSelected: _setRange,
                  ),
                  const SizedBox(height: 12),
                  _RingkasanGrid(ringkasan: data.ringkasan),
                  const SizedBox(height: 12),
                  _PerhatianRow(ringkasan: data.ringkasan),
                  const SizedBox(height: 16),

                  // Daftar unit (dengan filter status dari data per unit).
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Daftar Unit Armada',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        '${data.perUnit.length} unit',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatusChips(
                    units: data.perUnit,
                    selected: _statusFilter,
                    onSelected: (s) => setState(() => _statusFilter = s),
                  ),
                  const SizedBox(height: 8),
                  for (final unit in data.perUnit)
                    if (_statusFilter == null ||
                        unit.status?.toLowerCase() ==
                            _statusFilter!.toLowerCase())
                      _UnitCard(unit: unit, onTap: () => _openUnit(unit)),

                  const SizedBox(height: 16),
                  _RekapTable(rekap: data.rekapPerTanggal),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Pilihan rentang data monitoring (7 / 30 hari terakhir).
class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.filter,
    required this.tanggalDari,
    required this.tanggalSampai,
    required this.onSelected,
  });

  final ArmadaMonitoringFilter filter;
  final String tanggalDari;
  final String tanggalSampai;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final is7 = filter.dari != null;
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          label: const Text('7 hari'),
          selected: is7,
          onSelected: (_) => onSelected(7),
        ),
        ChoiceChip(
          label: const Text('30 hari'),
          selected: !is7,
          onSelected: (_) => onSelected(30),
        ),
        Text(
          '${fmtTanggal(tanggalDari)} – ${fmtTanggal(tanggalSampai)}',
          style: TextStyle(fontSize: 11, color: colors.textTertiary),
        ),
      ],
    );
  }
}

/// Kartu KPI (bagian atas ringkasan 21.11).
///
/// Layout memakai `Wrap` + `LayoutBuilder` (bukan `GridView.count` dengan
/// `childAspectRatio` tetap) supaya tinggi tiap kartu menyesuaikan isinya
/// sendiri — aman terhadap font scaling besar (§22.8) dan label 2 kata
/// (mis. "Pemakaian HM") tanpa memaksa kartu jadi terlalu pendek/overflow.
class _RingkasanGrid extends StatelessWidget {
  const _RingkasanGrid({required this.ringkasan});

  final ArmadaMonitoringRingkasan ringkasan;

  @override
  Widget build(BuildContext context) {
    final r = ringkasan;
    final cards = <({String label, String value, IconData icon, Color color})>[
      (
        label: 'Total Armada',
        value: '${r.totalArmada} unit',
        icon: Icons.local_shipping_outlined,
        color: Colors.blue,
      ),
      (
        label: 'Hari Operasi',
        value: fmtRibuan(r.totalHariUnitOperasi),
        icon: Icons.calendar_month_outlined,
        color: Colors.indigo,
      ),
      (
        label: 'Jam Aktif',
        value: fmtJam(r.totalJamAktif),
        icon: Icons.schedule_outlined,
        color: Colors.purple,
      ),
      (
        label: 'HM/Jam',
        value: r.rasioHmJam == null ? '-' : fmtNum(r.rasioHmJam),
        icon: Icons.speed_outlined,
        color: Colors.pink,
      ),
      (
        label: 'Pemakaian HM',
        value: fmtNum(r.totalHm),
        icon: Icons.circle_outlined,
        color: Colors.teal,
      ),
      (
        label: 'Total Tempuh',
        value: fmtKm(r.totalOdoKm),
        icon: Icons.route_outlined,
        color: Colors.green,
      ),
      (
        label: 'Total Ritase',
        value: fmtRitase(r.totalRitase),
        icon: Icons.swap_vert_circle_outlined,
        color: Colors.amber,
      ),
      (
        label: 'Total Solar',
        value: fmtLiter(r.totalSolarLiter),
        icon: Icons.local_gas_station_outlined,
        color: Colors.orange,
      ),
    ];

    return Semantics(
      label:
          'Ringkasan utilisasi armada. '
          '${cards.map((c) => '${c.label}: ${c.value}').join(', ')}.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 8.0;
          // Tetap 2 kolom (konvensi kartu summary/dashboard di proyek ini,
          // §22.8), tapi lebar dihitung dari constraints aktual — bukan
          // GridView aspect-ratio — biar tinggi kartu bebas menyesuaikan isi.
          final itemWidth = (constraints.maxWidth - spacing) / 2;
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              Icon(c.icon, size: 14, color: c.color),
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
          Text(
            c.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Baris perhatian: unit bermasalah / belum checklist / downtime / servis.
///
/// Wrap otomatis 2 kolom di layar sempit (bukan dipaksa 4 kolom sejajar)
/// supaya label seperti "Belum checklist" tidak kepepet/terpotong.
class _PerhatianRow extends StatelessWidget {
  const _PerhatianRow({required this.ringkasan});

  final ArmadaMonitoringRingkasan ringkasan;

  @override
  Widget build(BuildContext context) {
    final items = <({String label, int value, Color color, IconData icon})>[
      (
        label: 'Bermasalah',
        value: ringkasan.unitBermasalah,
        color: Colors.red,
        icon: Icons.warning_amber_outlined,
      ),
      (
        label: 'Belum checklist',
        value: ringkasan.belumChecklistHariIni,
        color: Colors.amber,
        icon: Icons.checklist_rtl,
      ),
      (
        label: 'Downtime',
        value: ringkasan.downtimeAktif,
        color: Colors.orange,
        icon: Icons.construction_outlined,
      ),
      (
        label: 'Servis menunggu',
        value: ringkasan.servisMenunggu,
        color: Colors.blue,
        icon: Icons.medical_services_outlined,
      ),
    ];

    return Semantics(
      label:
          'Perlu perhatian. '
          '${items.map((e) => '${e.label}: ${e.value}').join(', ')}.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 6.0;
          // 4 kolom kalau ada cukup ruang per item (>= 84dp), kalau tidak
          // turun ke 2 kolom (2x2) daripada memaksa 4 kolom sempit.
          final columns = constraints.maxWidth / 4 >= 84 ? 4 : 2;
          final itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final e in items)
                SizedBox(
                  width: itemWidth,
                  child: _PerhatianTile(e: e),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PerhatianTile extends StatelessWidget {
  const _PerhatianTile({required this.e});

  final ({String label, int value, Color color, IconData icon}) e;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: e.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(e.icon, size: 16, color: e.color),
          const SizedBox(height: 4),
          Text(
            '${e.value}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: e.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            e.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: e.color),
          ),
        ],
      ),
    );
  }
}

/// Chip filter status unit dari data per unit (tap untuk memfilter).
class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.units,
    required this.selected,
    required this.onSelected,
  });

  final List<ArmadaMonitoringUnit> units;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final statuses = <String, int>{};
    for (final u in units) {
      final s = u.status ?? 'aktif';
      statuses[s] = (statuses[s] ?? 0) + 1;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('Semua (${units.length})'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final e in statuses.entries)
          ChoiceChip(
            label: Text('${e.key} (${e.value})'),
            selected: selected?.toLowerCase() == e.key.toLowerCase(),
            onSelected: (_) => onSelected(
              selected?.toLowerCase() == e.key.toLowerCase() ? null : e.key,
            ),
          ),
      ],
    );
  }
}

/// Kartu satu unit: identitas, kondisi, checklist + metrik utilisasi.
class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.onTap});

  final ArmadaMonitoringUnit unit;

  /// Membuka drill-down data unit ini.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final statusColor = armadaStatusColor(context, unit.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    child: Icon(
                      unit.tipeUnit == 'alat_berat'
                          ? Icons.precision_manufacturing_outlined
                          : Icons.local_shipping_outlined,
                      size: 18,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.platNomor ?? unit.kodeUnit ?? 'Unit ${unit.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          [
                            if (unit.kodeUnit != null &&
                                unit.kodeUnit!.isNotEmpty)
                              'Unit ${unit.kodeUnit}',
                            labelJenisArmada(unit.jenis),
                            if (unit.unitBisnisKode != null &&
                                unit.unitBisnisKode!.isNotEmpty)
                              unit.unitBisnisKode!,
                          ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unit.status ?? 'aktif',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (unit.kondisiTerakhir != null)
                    _Tag(
                      icon: unit.kondisiTerakhir!.kondisiBaik
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      label: unit.kondisiTerakhir!.kondisiBaik
                          ? 'Kondisi baik'
                          : (unit.kondisiTerakhir!.itemBermasalah ??
                                'Bermasalah'),
                      color: unit.kondisiTerakhir!.kondisiBaik
                          ? colors.success
                          : colors.error,
                    ),
                  if (unit.checklistHariIni)
                    _Tag(
                      icon: Icons.checklist_rtl,
                      label: 'Checklist hari ini',
                      color: colors.success,
                    )
                  else
                    _Tag(
                      icon: Icons.checklist_rtl,
                      label: 'Belum checklist',
                      color: colors.warning,
                    ),
                  if (unit.downtimeAktif)
                    _Tag(
                      icon: Icons.construction_outlined,
                      label: 'Downtime aktif',
                      color: colors.warning,
                    ),
                  if (unit.servisMenunggu)
                    _Tag(
                      icon: Icons.medical_services_outlined,
                      label: 'Servis',
                      color: colors.info,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Metrik Jam/ODO/HM/Rit: lebar per item dihitung dari ruang
              // tersedia (bukan Expanded rata 4 kolom tetap) supaya nilai
              // panjang (mis. "125.000 km") tidak terpotong "..." — lihat
              // FittedBox di _Metric untuk pengaman tambahan.
              LayoutBuilder(
                builder: (context, constraints) {
                  final metrics =
                      <({IconData icon, String label, String value})>[
                        (
                          icon: Icons.schedule_outlined,
                          label: 'Jam',
                          value: fmtJam(unit.totalJamAktif),
                        ),
                        (
                          icon: Icons.speed_outlined,
                          label: 'ODO',
                          value: fmtKm(unit.totalOdoKm),
                        ),
                        (
                          icon: Icons.circle_outlined,
                          label: 'HM',
                          value: fmtNum(unit.totalHm),
                        ),
                        (
                          icon: Icons.swap_vert_circle_outlined,
                          label: 'Rit',
                          value: fmtRitase(unit.jumlahRit),
                        ),
                      ];

                  const minItemWidth = 72.0;
                  final rawColumns = (constraints.maxWidth / minItemWidth)
                      .floor();
                  final columns = rawColumns.clamp(2, metrics.length);
                  final itemWidth = constraints.maxWidth / columns;

                  return Wrap(
                    runSpacing: 6,
                    children: [
                      for (final m in metrics)
                        SizedBox(
                          width: itemWidth,
                          child: _Metric(
                            icon: m.icon,
                            label: m.label,
                            value: m.value,
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (unit.rasioHmJam != null) ...[
                const SizedBox(height: 6),
                Text(
                  'HM/Jam ${fmtNum(unit.rasioHmJam)} • '
                  'Hari operasi ${unit.jumlahHariOperasi}',
                  style: TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textTertiary),
          const SizedBox(height: 2),
          // FittedBox: nilai mengecil otomatis kalau tidak muat, bukan
          // dipotong "..." — penting untuk dashboard monitoring supaya
          // angka tetap utuh terbaca.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Tabel rekap durasi per tanggal (mirror "REKAP HARIAN PERALATAN").
///
/// Kolom pakai lebar tetap (bukan `Expanded` rata) supaya angka tidak
/// pernah terpotong "..."; kalau layar lebih sempit dari total lebar
/// kolom, tabel di-scroll horizontal alih-alih memaksa menyempit.
class _RekapTable extends StatelessWidget {
  const _RekapTable({required this.rekap});

  final List<ArmadaMonitoringRekap> rekap;

  // Tanggal 84 + Unit 44 + Jam 60 + HM 60 + ODO km 76 + Rit 44
  // + spacing 10 x 5 kolom antar-sel = 418.
  static const double _minWidth = 418;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                  color: colors.info,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rekap Durasi per Tanggal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth > _minWidth
                    ? constraints.maxWidth
                    : _minWidth;
                final table = SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      _RekapHeader(colors: colors),
                      const Divider(height: 12),
                      for (final d in rekap.reversed) _RekapRow(rekap: d),
                    ],
                  ),
                );

                if (constraints.maxWidth >= _minWidth) return table;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geser untuk lihat semua kolom →',
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: table,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RekapHeader extends StatelessWidget {
  const _RekapHeader({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, double width, TextAlign align) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color:
              colors.textTertiary, // dulu hardcode Colors.grey (bug dark mode)
        ),
      ),
    );

    return Row(
      children: [
        cell('Tanggal', 84, TextAlign.left),
        const SizedBox(width: 10),
        cell('Unit', 44, TextAlign.center),
        const SizedBox(width: 10),
        cell('Jam', 60, TextAlign.right),
        const SizedBox(width: 10),
        cell('HM', 60, TextAlign.right),
        const SizedBox(width: 10),
        cell('ODO km', 76, TextAlign.right),
        const SizedBox(width: 10),
        cell('Rit', 44, TextAlign.right),
      ],
    );
  }
}

class _RekapRow extends StatelessWidget {
  const _RekapRow({required this.rekap});

  final ArmadaMonitoringRekap rekap;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, double width, TextAlign align) => SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          cell(fmtTanggal(rekap.tanggal), 84, TextAlign.left),
          const SizedBox(width: 10),
          cell('${rekap.jumlahUnit}', 44, TextAlign.center),
          const SizedBox(width: 10),
          cell(fmtNum(rekap.totalJamAktif), 60, TextAlign.right),
          const SizedBox(width: 10),
          cell(fmtNum(rekap.totalHm), 60, TextAlign.right),
          const SizedBox(width: 10),
          cell(fmtNum(rekap.totalOdoKm), 76, TextAlign.right),
          const SizedBox(width: 10),
          cell('${rekap.jumlahRit}', 44, TextAlign.right),
        ],
      ),
    );
  }
}
