import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/workflow_stepper.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

class UnitSayaHomeScreen extends ConsumerStatefulWidget {
  const UnitSayaHomeScreen({super.key});

  @override
  ConsumerState<UnitSayaHomeScreen> createState() => _UnitSayaHomeScreenState();
}

class _UnitSayaHomeScreenState extends ConsumerState<UnitSayaHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);
    final ritaseAsync = ref.watch(ritaseRiwayatProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Unit Saya',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(armadaSayaProvider);
          ref.invalidate(checklistHariIniProvider);
          await ref.read(ritaseRiwayatProvider.notifier).refresh();
        },
        child: armadaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppEmptyState(
                  icon: Icons.error_outline,
                  title: 'Gagal memuat data unit',
                  subtitle: '$e',
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 48),
                    child: AppEmptyState(
                      icon: Icons.no_crash_outlined,
                      title: 'Belum ada unit yang ditugaskan',
                      subtitle: 'Hubungi admin untuk penugasan unit.',
                    ),
                  ),
                ],
              );
            }

            final armada = items.first;
            final checklists = checklistAsync.value ?? [];
            final ritItems = ritaseAsync.items;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _UnitHeader(armada: armada),
                const SizedBox(height: 4),
                _WorkflowSection(
                  armada: armada,
                  checklists: checklists,
                  ritItems: ritItems,
                ),
                const SizedBox(height: 4),
                _RingkasanKerja(
                  armada: armada,
                  ritItems: ritItems,
                ),
                const SizedBox(height: 8),
                _ShortcutSection(armada: armada),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Unit Header ──────────────────────────────────────────────────────────────

class _UnitHeader extends StatelessWidget {
  const _UnitHeader({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final aktif = armada.status == 'aktif' || armada.status == 'beroperasi';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              armada.isAlatBerat
                  ? Icons.construction_rounded
                  : Icons.local_shipping_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      armada.platNomor,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (armada.kodeUnit != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        armada.kodeUnit!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        armada.isAlatBerat ? 'Alat Berat' : 'Kendaraan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: aktif ? const Color(0xFF4ADE80) : AppTheme.warningColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      aktif ? 'Aktif' : (armada.status ?? 'Standby'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                    if (armada.titikNama != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          armada.titikNama!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Workflow Section ─────────────────────────────────────────────────────────

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection({
    required this.armada,
    required this.checklists,
    required this.ritItems,
  });

  final ArmadaSaya armada;
  final List<ArmadaChecklist> checklists;
  final List<RitaseItem> ritItems;

  @override
  Widget build(BuildContext context) {
    final myChecklist = checklists.where((c) => c.armadaId == armada.id).toList();
    final hasChecklistPagi = myChecklist.any((c) => c.sudahIsi);
    final hasOdoAwal = myChecklist.any((c) =>
        armada.isAlatBerat
            ? (c.jamOperasional != null && c.jamOperasional! > 0)
            : (c.odoKm != null && c.odoKm! > 0));
    final ritCount = ritItems.length;
    final hasChecklistAkhir = hasChecklistPagi;

    final steps = [
      WorkflowStep(
        label: 'Checklist Unit',
        subtitle: hasChecklistPagi ? 'Sudah diisi' : 'Belum diisi',
        status: hasChecklistPagi
            ? WorkflowStepStatus.selesai
            : WorkflowStepStatus.sedang,
        onTap: () => context.push('/armada/checklist'),
      ),
      WorkflowStep(
        label: armada.isAlatBerat ? 'Jam Awal' : 'ODO Awal',
        subtitle: hasOdoAwal
            ? (armada.isAlatBerat
                ? 'Tercatat'
                : 'Sudah diisi')
            : (armada.odoTerkini != null
                ? (armada.isAlatBerat
                    ? 'HM: ${armada.jamOperasionalTerkini ?? '-'} jam'
                    : 'ODO: ${armada.odoTerkini} km')
                : 'Belum diisi'),
        status: hasOdoAwal
            ? WorkflowStepStatus.selesai
            : WorkflowStepStatus.belum,
        onTap: () => context.push('/armada/odo-awal'),
      ),
      WorkflowStep(
        label: armada.isAlatBerat ? 'Jam Kerja Berjalan' : 'Ritase Berjalan',
        subtitle: armada.isAlatBerat
            ? (ritCount > 0 ? 'Aktif' : 'Belum ada data')
            : (ritCount > 0 ? '$ritCount rit tercatat' : 'Belum ada rit'),
        status: ritCount > 0
            ? WorkflowStepStatus.selesai
            : WorkflowStepStatus.belum,
        onTap: () => context.push('/armada/ritase'),
      ),
      WorkflowStep(
        label: 'Checklist Akhir',
        subtitle: hasChecklistAkhir ? 'Sudah diisi' : 'Belum diisi',
        status: hasChecklistAkhir
            ? WorkflowStepStatus.selesai
            : WorkflowStepStatus.belum,
        onTap: () => context.push('/armada/checklist-akhir'),
      ),
    ];

    return WorkflowStepper(steps: steps);
  }
}

// ── Ringkasan Kerja ──────────────────────────────────────────────────────────

class _RingkasanKerja extends StatelessWidget {
  const _RingkasanKerja({
    required this.armada,
    required this.ritItems,
  });

  final ArmadaSaya armada;
  final List<RitaseItem> ritItems;

  @override
  Widget build(BuildContext context) {
    final ritCount = ritItems.length;
    final totalUpah = ritItems.fold<double>(
      0,
      (sum, r) => sum + (r.totalUpahRit ?? 0),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    armada.isAlatBerat
                        ? Icons.timer_outlined
                        : Icons.assessment_outlined,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ringkasan Kerja',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: armada.isAlatBerat ? 'Jam Kerja' : 'Rit Hari Ini',
                      value: armada.isAlatBerat
                          ? fmtRitase(ritCount, 'jam')
                          : fmtRitase(ritCount),
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  if (armada.isKendaraan) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatBox(
                        label: 'Total Upah',
                        value: fmtRp(totalUpah),
                        color: AppTheme.successColor,
                      ),
                    ),
                  ],
                ],
              ),
              if (armada.isKendaraan) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/armada/ritase-input'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Input Ritase Baru'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shortcut Section ─────────────────────────────────────────────────────────

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akses Cepat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.build_outlined,
            title: 'Ajukan Servis',
            subtitle: 'Laporkan kerusakan unit',
            onTap: () => context.push(
              '/armada/servis/ajuan?armadaId=${armada.id}',
            ),
          ),
          _ShortcutTile(
            icon: Icons.history_rounded,
            title: 'Riwayat Servis',
            subtitle: 'Riwayat perbaikan unit',
            onTap: () => context.push('/armada/servis'),
          ),
          _ShortcutTile(
            icon: Icons.badge_outlined,
            title: 'Presensi Helper',
            subtitle: 'Absenkan helper hari ini',
            onTap: () => context.push('/armada/helper-presensi'),
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
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
      ),
    );
  }
}
