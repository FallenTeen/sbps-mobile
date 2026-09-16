import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../dashboard/dashboard_providers.dart';
import '../dashboard/models.dart';
import 'armada_monitoring.dart';
import 'armada_providers.dart';
import 'models/armada.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';
import 'unit_monitoring_screen.dart';

/// Overview Seluruh Armada — monitoring operasional yang bisa ditindaklanjuti.
///
/// Bukan sekadar deretan angka: chip ringkasan status bisa difilter, kartu
/// unit menampilkan unit, status, titik, ODO/HM (bila tersedia), peringatan
/// nyata (checklist belum diisi / servis aktif / unit non-operasi), dan tiap
/// unit bisa di-dig-down ke [UnitMonitoringScreen].
class OverviewArmadaScreen extends ConsumerStatefulWidget {
  const OverviewArmadaScreen({super.key});

  @override
  ConsumerState<OverviewArmadaScreen> createState() =>
      _OverviewArmadaScreenState();
}

class _OverviewArmadaScreenState extends ConsumerState<OverviewArmadaScreen> {
  String? _statusFilter;

  Future<void> _refresh() async {
    ref.invalidate(masterArmadaProvider);
    ref.invalidate(armadaStatusProvider);
    ref.invalidate(armadaSayaProvider);
    ref.invalidate(checklistHariIniProvider);
    ref.read(servisRiwayatProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final masterAsync = ref.watch(masterArmadaProvider);
    final statusAsync = ref.watch(armadaStatusProvider);
    final sayaAsync = ref.watch(armadaSayaProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);
    final servisState = ref.watch(servisRiwayatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Overview Seluruh Armada'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Chip status yang BISA difilter (bukan sekadar angka).
            _StatusFilterBar(
              statusAsync: statusAsync,
              selected: _statusFilter,
              onSelected: (s) => setState(() => _statusFilter = s),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Daftar Unit Armada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_statusFilter != null)
                  TextButton(
                    onPressed: () => setState(() => _statusFilter = null),
                    child: const Text('Hapus filter'),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            masterAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Center(
                child: Column(
                  children: [
                    Text('Gagal memuat data armada.'),
                    const SizedBox(height: 4),
                    Text(
                      friendlyErrorMessage(err),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(masterArmadaProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
              data: (armadaList) {
                if (armadaList.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Tidak ada unit armada terdaftar.'),
                      ),
                    ),
                  );
                }

                final filter = _statusFilter;
                final filtered = filter == null
                    ? armadaList
                    : [
                        for (final a in armadaList)
                          if (a.status?.toLowerCase() ==
                              filter.toLowerCase())
                            a,
                      ];

                if (filtered.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Tidak ada unit "$filter"',
                    subtitle: 'Tidak ada unit dengan status filter ini.',
                    actionLabel: 'Hapus filter',
                    onAction: () => setState(() => _statusFilter = null),
                  );
                }

                // Data pelengkap (hanya ditampilkan "bila tersedia").
                final sayaList = sayaAsync.value ?? const <ArmadaSaya>[];
                final checklistList =
                    checklistAsync.value ?? const <ArmadaChecklist>[];
                final sayaById = {for (final s in sayaList) s.id: s};
                final checklistById = {
                  for (final c in checklistList) c.armadaId: c,
                };

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final unit in filtered)
                      _MonitorArmadaTile(
                        unit: unit,
                        saya: sayaById[unit.id],
                        checklist: checklistById[unit.id],
                        servis: servisState.items
                            .where((s) => s.armadaId == unit.id)
                            .toList(),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  UnitMonitoringScreen(unit: unit),
                            ),
                          );
                        },
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

/// Baris chip status ringkasan yang dapat diketuk untuk memfilter daftar unit.
class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({
    required this.statusAsync,
    required this.selected,
    required this.onSelected,
  });

  final AsyncValue<ArmadaStatusData> statusAsync;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;

    return statusAsync.when(
      loading: () => const SkeletonListView(itemCount: 1, padding: EdgeInsets.zero),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gagal memuat ringkasan status: ${friendlyErrorMessage(error)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (statusData) {
        if (statusData.items.isEmpty) return const SizedBox.shrink();

        final allCount = statusData.items.fold<int>(
          0,
          (sum, e) => sum + e.jumlah,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Unit — tap untuk filter',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChipButton(
                  label: 'Semua',
                  count: allCount,
                  color: colors.textPrimary,
                  selected: selected == null,
                  onTap: () => onSelected(null),
                ),
                for (final e in statusData.items)
                  _FilterChipButton(
                    label: e.status,
                    count: e.jumlah,
                    color: armadaStatusColor(context, e.status),
                    selected:
                        selected?.toLowerCase() == e.status.toLowerCase(),
                    onTap: () => onSelected(e.status),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Satu chip jumlah status yang bisa diketuk untuk filter.
class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? color : color.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu satu unit armada yang kaya informasi (unit, status, titik, ODO/HM,
/// peringatan, tombol drill-down).
class _MonitorArmadaTile extends StatelessWidget {
  const _MonitorArmadaTile({
    required this.unit,
    required this.saya,
    required this.checklist,
    required this.servis,
    required this.onTap,
  });

  final MasterArmada unit;

  /// Data pelengkap dari `/armada/saya` (titik/ODO/HM) — bila tersedia.
  final ArmadaSaya? saya;

  /// Checklist hari ini unit ini dari `/armada/checklist-hari-ini`.
  final ArmadaChecklist? checklist;

  /// Servis unit ini (dari halaman pertama `/servis-armada`).
  final List<ServisArmada> servis;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final color = armadaStatusColor(context, unit.status);
    final warnings = unitWarnings(
      status: unit.status,
      checklistKnown: checklist != null,
      checklistSudahIsi: checklist?.sudahIsi ?? false,
      servis: servis,
    );

    final isAlatBerat = saya?.isAlatBerat ?? false;
    final titikNama = saya?.titikNama;
    final odoKm = isAlatBerat ? null : saya?.odoTerkini;
    final jamOperasional = isAlatBerat ? saya?.jamOperasionalTerkini : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(
                      isAlatBerat
                          ? Icons.precision_manufacturing_outlined
                          : Icons.local_shipping_outlined,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.platNomor,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          [
                            if (unit.kodeUnit != null &&
                                unit.kodeUnit!.isNotEmpty)
                              'Unit ${unit.kodeUnit}',
                            if (unit.jenis != null && unit.jenis!.isNotEmpty)
                              unit.jenis!,
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 12,
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unit.status ?? 'Aktif',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (titikNama != null)
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: titikNama,
                    color: colors.textSecondary,
                  ),
                if (odoKm != null)
                  _InfoChip(
                    icon: Icons.speed_outlined,
                    label: fmtKm(odoKm),
                    color: colors.textSecondary,
                  ),
                if (jamOperasional != null)
                  _InfoChip(
                    icon: Icons.schedule_outlined,
                    label: fmtJam(jamOperasional),
                    color: colors.textSecondary,
                  ),
                for (final w in warnings)
                  _InfoChip(
                    icon: w.icon,
                    label: w.message,
                    color: colors.warning,
                  ),
              ],
            ),
            if (warnings.isEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: colors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tidak ada peringatan',
                    style: TextStyle(fontSize: 11, color: colors.success),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Lihat Detail Unit'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final surfaceVariant =
        Theme.of(context).extension<AppColors>()?.surfaceVariant ??
        Colors.grey.shade100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}