import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'armada_monitoring.dart';
import 'armada_providers.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';
import 'servis_status.dart';

/// Drill-down satu unit armada — monitoring operasional yang dapat ditindaklanjuti.
///
/// Menampilkan: informasi unit, status, titik, ODO/HM (bila tersedia),
/// peringatan nyata, dan riwayat servis unit ini beserta aksi (ajukan servis,
/// lihat semua servis, buka detail servis).
class UnitMonitoringScreen extends ConsumerWidget {
  const UnitMonitoringScreen({super.key, required this.unit});

  final MasterArmada unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final color = armadaStatusColor(context, unit.status);

    final sayaAsync = ref.watch(armadaSayaProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);
    final servisAsync = ref.watch(servisArmadaUnitProvider(unit.id));

    final saya = sayaAsync.value?.where((s) => s.id == unit.id).firstOrNull;
    final checklist = checklistAsync.value
        ?.where((c) => c.armadaId == unit.id)
        .firstOrNull;

    final isAlatBerat = saya?.isAlatBerat ?? unit.isAlatBerat;
    final odoKm = isAlatBerat ? null : (saya?.odoTerkini ?? unit.odoTerkini ?? checklist?.odoKm);
    final jamOperasional = isAlatBerat
        ? (saya?.jamOperasionalTerkini ?? unit.jamOperasionalTerkini ?? checklist?.jamOperasional)
        : null;
    final titikNama = saya?.titikNama ?? unit.titikNama;

    final servis = servisAsync.value ?? const <ServisArmada>[];
    final warnings = unitWarnings(
      status: unit.status,
      checklistKnown: checklist != null,
      checklistSudahIsi: checklist?.sudahIsi ?? false,
      servis: servis,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(unit.platNomor),
        actions: const [PortalSwitchButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info unit ─────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Icon(
                          isAlatBerat
                              ? Icons.precision_manufacturing_outlined
                              : Icons.local_shipping_outlined,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.platNomor,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                if (unit.kodeUnit != null &&
                                    unit.kodeUnit!.isNotEmpty)
                                  'Unit ${unit.kodeUnit}',
                                if (unit.jenis != null &&
                                    unit.jenis!.isNotEmpty)
                                  unit.jenis!,
                              ].join(' • '),
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unit.status ?? 'Aktif',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (titikNama != null)
                        _UnitInfoChip(
                          icon: Icons.location_on_outlined,
                          label: 'Titik: $titikNama',
                        ),
                      if (odoKm != null)
                        _UnitInfoChip(
                          icon: Icons.speed_outlined,
                          label: 'ODO: ${fmtKm(odoKm)}',
                        ),
                      if (jamOperasional != null)
                        _UnitInfoChip(
                          icon: Icons.schedule_outlined,
                          label: 'HM: ${fmtJam(jamOperasional)}',
                        ),
                      if (saya == null)
                        _UnitInfoChip(
                          icon: Icons.badge_outlined,
                          label: 'Status: ${unit.status ?? 'Aktif'}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Peringatan (dari data nyata) ─────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perhatian',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (warnings.isEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 18,
                          color: colors.success,
                        ),
                        const SizedBox(width: 8),
                        const Text('Tidak ada peringatan.'),
                      ],
                    )
                  else
                    for (final w in warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(w.icon, size: 18, color: colors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                w.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Aksi ─────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    '/armada/servis/ajuan?armadaId=${unit.id}',
                  ),
                  icon: const Icon(Icons.add_alert_outlined, size: 18),
                  label: const Text('Ajukan Servis'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/armada/servis'),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('Semua Servis'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Riwayat servis unit ini ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'Riwayat Servis Unit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (servisAsync.isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),

          servisAsync.when(
            loading: () => const SkeletonListView(
              itemCount: 2,
              padding: EdgeInsets.zero,
            ),
            error: (e, _) => AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Gagal memuat riwayat servis',
              subtitle: friendlyErrorMessage(e),
              actionLabel: 'Coba lagi',
              onAction: () => ref.invalidate(servisArmadaUnitProvider(unit.id)),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.build_outlined,
                  title: 'Belum Ada Riwayat Servis',
                  subtitle: 'Unit ini belum pernah diajukan servis.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final sv in list)
                    _ServisTile(item: sv),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UnitInfoChip extends StatelessWidget {
  const _UnitInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textTertiary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Baris satu servis unit — tap untuk membuka detail.
class _ServisTile extends StatelessWidget {
  const _ServisTile({required this.item});

  final ServisArmada item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    final color = servisStatusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            switch (item.status) {
              'selesai' => Icons.verified_outlined,
              'ditolak' => Icons.cancel_outlined,
              _ => Icons.build_outlined,
            },
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          item.keluhan,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          [
            servisStatusLabel(item.status),
            if (item.tanggalAjuan.isNotEmpty)
              fmtTanggal(item.tanggalAjuan),
            if (item.status == 'selesai' && item.totalBiaya != null)
              fmtRp(item.totalBiaya!),
          ].join(' • '),
          style: TextStyle(fontSize: 12, color: colors.textTertiary),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/armada/servis/${item.id}'),
      ),
    );
  }
}