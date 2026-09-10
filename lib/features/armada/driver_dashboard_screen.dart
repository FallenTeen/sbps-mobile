import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armadaAsync = ref.watch(armadaSayaProvider);
    final ritaseAsync = ref.watch(ritaseRiwayatProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: null,
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(armadaSayaProvider);
          ref.invalidate(checklistHariIniProvider);
          await ref.read(ritaseRiwayatProvider.notifier).refresh();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _VehicleSection(armadaAsync: armadaAsync),
            const SizedBox(height: 16),
            _TodaySummarySection(ritaseAsync: ritaseAsync),
            const SizedBox(height: 16),
            _ChecklistSection(checklistAsync: checklistAsync),
            const SizedBox(height: 16),
            _RecentRitaseSection(ritaseAsync: ritaseAsync),
          ],
        ),
      ),
    );
  }
}

// ── Vehicle Section ───────────────────────────────────────────────────────────

class _VehicleSection extends StatelessWidget {
  const _VehicleSection({required this.armadaAsync});

  final AsyncValue<List<ArmadaSaya>> armadaAsync;

  @override
  Widget build(BuildContext context) {
    return armadaAsync.when(
      loading: () => const SkeletonCard(),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
        ),
        child: Text('Gagal memuat kendaraan: $e',
            style: const TextStyle(color: AppTheme.errorColor)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Column(
              children: [
                Icon(Icons.local_shipping_outlined,
                    size: 40, color: AppTheme.textMuted),
                SizedBox(height: 10),
                Text(
                  'Belum ada kendaraan yang ditugaskan',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textTertiary),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_bus_rounded,
                    size: 20, color: AppTheme.primaryColor),
                SizedBox(width: 8),
                Text(
                  'Kendaraan Saya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final a in items) _VehicleCard(armada: a),
          ],
        );
      },
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final aktif = armada.status == 'aktif' || armada.status == 'beroperasi';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: aktif
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: aktif ? AppTheme.successColor : AppTheme.warningColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      armada.platNomor,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (armada.kodeUnit != null)
                      Text(
                        armada.kodeUnit!,
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: aktif
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  armada.status ?? '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: aktif ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (armada.jenis != null)
                _InfoChip(icon: Icons.category_outlined, label: _labelJenis(armada.jenis!)),
              if (armada.tahun != null)
                _InfoChip(icon: Icons.calendar_today, label: '${armada.tahun}'),
              if (armada.titikNama != null)
                _InfoChip(icon: Icons.place_outlined, label: armada.titikNama!),
              if (armada.kapasitas != null)
                _InfoChip(icon: Icons.scale, label: armada.kapasitas!),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Today Summary ─────────────────────────────────────────────────────────────

class _TodaySummarySection extends StatelessWidget {
  const _TodaySummarySection({required this.ritaseAsync});

  final RitaseRiwayatState ritaseAsync;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.today_rounded, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Ringkasan Hari Ini',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              if (ritaseAsync.loading && ritaseAsync.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (ritaseAsync.error != null && ritaseAsync.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Gagal memuat data',
                      style: TextStyle(color: AppTheme.errorColor)),
                );
              }

              final todayItems = ritaseAsync.items
                  .where((r) => r.tanggal != null && r.tanggal!.startsWith(today))
                  .toList();

              final totalRit = todayItems.length;
              final totalUpah = todayItems.fold<double>(
                  0, (sum, r) => sum + (r.totalUpahRit ?? 0));

              return Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      icon: Icons.route_rounded,
                      label: 'Total Rit',
                      value: '$totalRit',
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      icon: Icons.payments_outlined,
                      label: 'Total Upah',
                      value: fmtRpCompact(totalUpah),
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Checklist Section ─────────────────────────────────────────────────────────

class _ChecklistSection extends StatelessWidget {
  const _ChecklistSection({required this.checklistAsync});

  final AsyncValue<List<ArmadaChecklist>> checklistAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist_rounded, color: AppTheme.primaryColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Checklist Hari Ini',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          checklistAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Gagal memuat checklist',
                  style: TextStyle(color: AppTheme.errorColor)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Tidak ada kendaraan untuk checklist',
                      style: TextStyle(color: AppTheme.textTertiary)),
                );
              }

              return Column(
                children: [
                  for (final c in items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.sudahIsi
                            ? AppTheme.successColor.withValues(alpha: 0.04)
                            : AppTheme.surfaceVariantColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: c.sudahIsi
                              ? AppTheme.successColor.withValues(alpha: 0.2)
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/armada/checklist'),
                        child: Row(
                          children: [
                            Icon(
                              c.sudahIsi
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: c.sudahIsi
                                  ? AppTheme.successColor
                                  : AppTheme.textMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.platNomor,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    c.sudahIsi
                                        ? 'Sudah diisi${c.odoKm != null ? ' • ODO: ${fmtKm(c.odoKm!)}' : ''}'
                                        : 'Belum diisi',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Recent Ritase ─────────────────────────────────────────────────────────────

class _RecentRitaseSection extends StatelessWidget {
  const _RecentRitaseSection({required this.ritaseAsync});

  final RitaseRiwayatState ritaseAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Riwayat Muatan Terakhir',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/armada/ritase'),
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              if (ritaseAsync.loading && ritaseAsync.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (ritaseAsync.error != null && ritaseAsync.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Gagal memuat riwayat',
                      style: TextStyle(color: AppTheme.errorColor)),
                );
              }

              if (ritaseAsync.items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Belum ada riwayat muatan',
                      style: TextStyle(color: AppTheme.textTertiary)),
                );
              }

              final recent = ritaseAsync.items.take(5).toList();

              return Column(
                children: [
                  for (final r in recent)
                    _RitaseTile(ritase: r),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RitaseTile extends StatelessWidget {
  const _RitaseTile({required this.ritase});

  final RitaseItem ritase;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ritase.material ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              _RitaseStatusBadge(status: ritase.status),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (ritase.ruteAsal != null && ritase.ruteTujuan != null)
                Expanded(
                  child: Text(
                    '${ritase.ruteAsal} → ${ritase.ruteTujuan}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (ritase.totalUpahRit != null)
                Text(
                  fmtRpCompact(ritase.totalUpahRit!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          if (ritase.tanggal != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ritase.tanggal!,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Summary Tile ──────────────────────────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chips & Badges ────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RitaseStatusBadge extends StatelessWidget {
  const _RitaseStatusBadge({this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'disetujui' => AppTheme.successColor,
      'draft' => AppTheme.warningColor,
      'ditagih' => AppTheme.infoColor,
      _ => AppTheme.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status ?? '-',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _labelJenis(String jenis) => switch (jenis) {
      'dump_truck' => 'Dump Truck',
      'mixer_beton' => 'Mixer Beton',
      'excavator' => 'Excavator',
      'mobil_pickup' => 'Mobil Pickup',
      _ => jenis,
    };


