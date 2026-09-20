import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/armada_jenis.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../dashboard/dashboard_providers.dart';
import '../dashboard/models.dart';
import 'armada_monitoring.dart';

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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(armadaMonitoringProvider(_filter));
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Armada'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
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
                    _UnitCard(unit: unit),

                const SizedBox(height: 16),
                _RekapTable(rekap: data.rekapPerTanggal),
                const SizedBox(height: 24),
              ],
            );
          },
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

    return Row(
      children: [
        ChoiceChip(
          label: const Text('7 hari'),
          selected: is7,
          onSelected: (_) => onSelected(7),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('30 hari'),
          selected: !is7,
          onSelected: (_) => onSelected(30),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            '${fmtTanggal(tanggalDari)} – ${fmtTanggal(tanggalSampai)}',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Kartu KPI (bagian atas ringkasan 21.11).
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

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [
        for (final c in cards)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(c.icon, size: 14, color: c.color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        c.label,
                        maxLines: 1,
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
                const Spacer(),
                Text(
                  c.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Baris perhatian: unit bermasalah / belum checklist / downtime / servis.
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

    return Row(
      children: [
        for (final e in items)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: e.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
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
                  Text(
                    e.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: e.color),
                  ),
                ],
              ),
            ),
          ),
      ],
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
  const _UnitCard({required this.unit});

  final ArmadaMonitoringUnit unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final statusColor = armadaStatusColor(context, unit.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
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
            Row(
              children: [
                _Metric(
                  icon: Icons.schedule_outlined,
                  label: 'Jam',
                  value: fmtJam(unit.totalJamAktif),
                ),
                _Metric(
                  icon: Icons.speed_outlined,
                  label: 'ODO',
                  value: fmtKm(unit.totalOdoKm),
                ),
                _Metric(
                  icon: Icons.circle_outlined,
                  label: 'HM',
                  value: fmtNum(unit.totalHm),
                ),
                _Metric(
                  icon: Icons.swap_vert_circle_outlined,
                  label: 'Rit',
                  value: fmtRitase(unit.jumlahRit),
                ),
              ],
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
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: colors.textTertiary),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
class _RekapTable extends StatelessWidget {
  const _RekapTable({required this.rekap});

  final List<ArmadaMonitoringRekap> rekap;

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
                Text(
                  'Rekap Durasi per Tanggal',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _RekapHeader(),
            const Divider(height: 1),
            for (final d in rekap.reversed) _RekapRow(rekap: d),
          ],
        ),
      ),
    );
  }
}

class _RekapHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {TextAlign align = TextAlign.left}) => Expanded(
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
        ),
      ),
    );

    return Row(
      children: [
        cell('Tanggal'),
        cell('Unit', align: TextAlign.center),
        cell('Jam', align: TextAlign.right),
        cell('HM', align: TextAlign.right),
        cell('ODO km', align: TextAlign.right),
        cell('Rit', align: TextAlign.right),
      ],
    );
  }
}

class _RekapRow extends StatelessWidget {
  const _RekapRow({required this.rekap});

  final ArmadaMonitoringRekap rekap;

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, {TextAlign align = TextAlign.left}) => Expanded(
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
          cell(fmtTanggal(rekap.tanggal)),
          cell('${rekap.jumlahUnit}', align: TextAlign.center),
          cell(fmtNum(rekap.totalJamAktif), align: TextAlign.right),
          cell(fmtNum(rekap.totalHm), align: TextAlign.right),
          cell(fmtNum(rekap.totalOdoKm), align: TextAlign.right),
          cell('${rekap.jumlahRit}', align: TextAlign.right),
        ],
      ),
    );
  }
}
