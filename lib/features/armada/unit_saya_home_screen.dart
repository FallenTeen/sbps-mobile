import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/armada_jenis.dart';
import '../../core/outbox/pending_action.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_top_bar_actions.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/brand_strip.dart';
import '../auth/auth_providers.dart';
import '../presensi/presensi_providers.dart';
import 'armada_providers.dart';
import 'checklist_model.dart';
import 'models/armada.dart';

/// Driver Home — pusat pekerjaan harian driver (dr docs §PHASE 07).
///
/// Menjawab: unit saya apa, lokasi saya di mana, apa yang selesai, apa yang
/// berikutnya, dan apa yang bermasalah hari ini.
class UnitSayaHomeScreen extends ConsumerStatefulWidget {
  const UnitSayaHomeScreen({super.key});

  @override
  ConsumerState<UnitSayaHomeScreen> createState() => _UnitSayaHomeScreenState();
}

class _UnitSayaHomeScreenState extends ConsumerState<UnitSayaHomeScreen> {
  /// Unit yang dipilih driver (hanya relevan saat penugasan > 1 unit).
  ArmadaSaya? _selected;

  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);
    final ritaseAsync = ref.watch(ritaseRiwayatProvider);
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text(
          'Unit Saya',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        bottom: const BrandStrip(),
        actions: const [AppTopBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          ref.invalidate(armadaSayaProvider);
          ref.invalidate(checklistHariIniProvider);
          await ref.read(ritaseRiwayatProvider.notifier).refresh();
        },
        child: armadaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Gagal memuat data unit',
                  subtitle:
                      'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
                  actionLabel: 'Coba Lagi',
                  onAction: () {
                    ref.invalidate(armadaSayaProvider);
                    ref.invalidate(checklistHariIniProvider);
                    ref.invalidate(ritaseRiwayatProvider);
                  },
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
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

            // M-03: driver bisa ditugaskan > 1 unit — Beranda harus bisa
            // menampilkan & berpindah antar unit, bukan diam-diam memakai
            // unit pertama saja.
            ArmadaSaya armada = items.first;
            if (items.length > 1) {
              final sel = _selected;
              if (sel != null && items.any((a) => a.id == sel.id)) {
                armada = sel;
              }
            }
            final checklists = checklistAsync.value ?? [];
            final ritItems = ritaseAsync.items;
            final today = DateTime.now().toIso8601String().substring(0, 10);
            final todayRitItems = ritItems
                .where((r) => r.tanggal != null && r.tanggal!.startsWith(today))
                // Multi-unit: jangan campurkan muatan unit lain ke ringkasan
                // unit terpilih (ritase tanpa armada_id dianggap milik
                // driver — tetap tampil).
                .where(
                  (r) =>
                      items.length == 1 ||
                      r.armadaId == null ||
                      r.armadaId == armada.id,
                )
                .toList();
            final myChecklists = checklists
                .where((c) => c.armadaId == armada.id)
                .toList();
            final akhirDone =
                myChecklists.any((c) => c.akhir != null) ||
                (ref.watch(checklistAkhirDoneProvider(armada.id)).value ??
                    false);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _GreetingHeader(nama: user?.name),
                if (items.length > 1) ...[
                  _UnitSwitcher(
                    items: items,
                    selectedId: armada.id,
                    onChanged: (a) {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = a);
                    },
                  ),
                ],
                const SizedBox(height: 4),
                _UnitSayaSection(armada: armada),
                if (armada.dokumenBerkala.any((d) => d.isJatuhTempoSegera)) ...[
                  const SizedBox(height: 4),
                  _DokumenBerkalaBanner(
                    dokumenList: armada.dokumenBerkala
                        .where((d) => d.isJatuhTempoSegera)
                        .toList(),
                  ),
                ],
                const SizedBox(height: 4),
                _PekerjaanHariIni(
                  armada: armada,
                  checklists: checklists,
                  ritItems: todayRitItems,
                  akhirDone: akhirDone,
                ),
                if (checklists.any(
                  (c) =>
                      unitChecklistStatus(c) == ChecklistUnitStatus.bermasalah,
                )) ...[
                  const SizedBox(height: 4),
                  _MasalahSection(checklists: checklists),
                ],
                const SizedBox(height: 4),
                _RingkasanKerja(armada: armada, ritItems: todayRitItems),
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

// ── Greeting ─────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({this.nama});

  final String? nama;

  @override
  Widget build(BuildContext context) {
    final label = (nama == null || nama!.trim().isEmpty)
        ? 'Driver'
        : nama!.trim().split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, $label',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fmtTanggalPanjang(DateTime.now()),
            style: TextStyle(fontSize: 13, color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── Unit switcher (multi-unit, M-03) ─────────────────────────────────────────

class _UnitSwitcher extends StatelessWidget {
  const _UnitSwitcher({
    required this.items,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ArmadaSaya> items;
  final String selectedId;
  final ValueChanged<ArmadaSaya> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          children: [
            for (final a in items)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(a.platNomor),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        a.id == selectedId ? FontWeight.w700 : FontWeight.w500,
                  ),
                  selected: a.id == selectedId,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onChanged(a),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Unit Saya ────────────────────────────────────────────────────────────────

class _UnitSayaSection extends StatelessWidget {
  const _UnitSayaSection({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final aktif = armada.status == 'aktif' || armada.status == 'beroperasi';
    final odoLabel = armada.isAlatBerat ? 'HM terakhir' : 'ODO terakhir';
    final odoValue = armada.isAlatBerat
        ? (armada.jamOperasionalTerkini != null
              ? fmtJam(armada.jamOperasionalTerkini)
              : 'Belum tercatat')
        : (armada.odoTerkini != null
              ? fmtKm(armada.odoTerkini)
              : 'Belum tercatat');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit Saya',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colors.primary,
                  context.colors.primary.withValues(alpha: 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: armada.fotoUrl != null && armada.fotoUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                armada.fotoUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  armada.isAlatBerat
                                      ? Icons.construction_rounded
                                      : Icons.local_shipping_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            )
                          : Icon(
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
                              Flexible(
                                child: Text(
                                  armada.platNomor,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
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
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            armada.jenis != null
                                ? _labelJenis(armada.jenis!)
                                : (armada.isAlatBerat
                                      ? 'Alat Berat'
                                      : 'Kendaraan'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          armada.titikNama ?? 'Titik belum ditetapkan',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: aktif
                              ? const Color(0xFF4ADE80)
                              : context.colors.warning,
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
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        armada.isAlatBerat
                            ? Icons.timer_outlined
                            : Icons.speed_outlined,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        odoLabel,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        odoValue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pekerjaan Hari Ini ───────────────────────────────────────────────────────

class _DayStep {
  const _DayStep({
    required this.number,
    required this.label,
    required this.done,
    required this.route,
    required this.cta,
    required this.subtitle,
    this.optional = false,
  });

  final int number;
  final String label;
  final bool done;
  final String route;
  final String cta;
  final String subtitle;

  /// Langkah opsional tidak menghalangi langkah berikutnya dan tidak
  /// dihitung dalam progres wajib (mis. Pengisian Solar).
  final bool optional;
}

class _PekerjaanHariIni extends ConsumerWidget {
  const _PekerjaanHariIni({
    required this.armada,
    required this.checklists,
    required this.ritItems,
    required this.akhirDone,
  });

  final ArmadaSaya armada;
  final List<ArmadaChecklist> checklists;
  final List<RitaseItem> ritItems;
  final bool akhirDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myChecklists = checklists
        .where((c) => c.armadaId == armada.id)
        .toList();

    // M-05: submission offline (masih di outbox) tidak terlihat di data
    // server — tanpa overlay ini driver menganggap datanya hilang dan
    // mengisi ulang. Flag step menyala juga untuk data yang masih lokal.
    final pending =
        ref.watch(pendingActionsProvider).value ?? const <PendingAction>[];
    bool hasPendingSync(PendingEndpoint endpoint) => pending.any(
      (a) =>
          a.endpoint == endpoint &&
          a.payloadData['armada_id']?.toString() == armada.id,
    );
    final pendingChecklistAwal = hasPendingSync(
      PendingEndpoint.armadaChecklistAwal,
    );
    final pendingPengisian = hasPendingSync(
      PendingEndpoint.armadaPengisianSolar,
    );
    final pendingRitase = hasPendingSync(PendingEndpoint.armadaRitase);
    final pendingChecklistAkhir = hasPendingSync(
      PendingEndpoint.armadaChecklistAkhir,
    );
    final kSync = 'Tersimpan — menunggu sinkronisasi';

    final hasChecklist =
        myChecklists.any((c) => c.sudahIsi) || pendingChecklistAwal;
    final ritCount = ritItems.length;

    final todayChecklist = myChecklists.firstOrNull;
    final pengisianCount = todayChecklist?.pengisian.length ?? 0;
    final pengisianLiter = todayChecklist?.totalLiterPengisian ?? 0;
    final hasPengisian = pengisianCount > 0 || pendingPengisian;

    final odoAwalAsync = ref.watch(odoAwalProyekProvider(armada.id));
    final showOdoAwalProyek = odoAwalAsync.value?.isEmpty == true;

    final activeRole = ref.watch(activeRoleProvider);
    final isOperatorAlatBerat =
        activeRole == 'Operator Alat Berat' || armada.isAlatBerat;

    final steps = [
      _DayStep(
        number: 1,
        label: 'Checklist Awal',
        done: hasChecklist,
        route: '/armada/checklist',
        cta: 'Isi checklist awal',
        subtitle: pendingChecklistAwal
            ? kSync
            : hasChecklist
            ? 'Sudah diperiksa'
            : 'Menunggu diperiksa',
      ),
      _DayStep(
        number: 2,
        label: 'Pengisian Solar',
        done: hasPengisian,
        route: '/armada/pengisian-solar',
        cta: 'Catat pengisian',
        subtitle: pendingPengisian && !hasPengisian
            ? kSync
            : hasPengisian
            ? (pengisianLiter > 0
                  ? '$pengisianCount kali • ${pengisianLiter % 1 == 0 ? pengisianLiter.toInt() : pengisianLiter.toStringAsFixed(1)} L'
                  : '$pengisianCount kali dicatat')
            : 'Belum ada pengisian',
        optional: true,
      ),
      if (!isOperatorAlatBerat)
        _DayStep(
          number: 3,
          label: 'Muatan / Jam Kerja',
          done: ritCount > 0 || pendingRitase,
          route: '/armada/ritase-input',
          cta: 'Catat muatan',
          subtitle: pendingRitase && ritCount == 0
              ? kSync
              : ritCount > 0
              ? '$ritCount muatan tercatat'
              : 'Belum ada muatan',
        ),
      _DayStep(
        number: isOperatorAlatBerat ? 3 : 4,
        label: 'Checklist Akhir',
        done: akhirDone || pendingChecklistAkhir,
        route: '/armada/checklist-akhir',
        cta: 'Isi checklist akhir',
        subtitle: pendingChecklistAkhir && !akhirDone
            ? kSync
            : akhirDone
            ? 'Sudah diisi'
            : 'Belum diisi',
      ),
    ];

    // Indikator menghitung SEMUA langkah yang tampil (termasuk Pengisian Solar
    // yang bersifat opsional). Langkah wajib tetap menentukan "Berikutnya" dan
    // status selesai: solar boleh dilewati tanpa menghalangi penyelesaian.
    final requiredSteps = steps.where((s) => !s.optional).toList();
    final doneCount = steps.where((s) => s.done).length;
    _DayStep? next;
    for (final s in requiredSteps) {
      if (!s.done) {
        next = s;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pekerjaan Hari Ini',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _ProgressCard(
            doneCount: doneCount,
            total: steps.length,
            next: next,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < steps.length; i++)
                  _NumStepTile(step: steps[i], isLast: i == steps.length - 1),
              ],
            ),
          ),
          if (showOdoAwalProyek) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/armada/odo-awal');
                },
                icon: const Icon(Icons.straighten_rounded, size: 18),
                label: const Text('Catat ODO Awal Proyek'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.doneCount,
    required this.total,
    required this.next,
  });

  final int doneCount;
  final int total;
  final _DayStep? next;

  @override
  Widget build(BuildContext context) {
    final allDone = next == null;
    final ratio = total == 0 ? 0.0 : doneCount / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? context.colors.success.withValues(alpha: 0.4)
              : context.colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$doneCount',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: allDone
                      ? context.colors.success
                      : context.colors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'dari $total selesai',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              if (allDone)
                Icon(
                  Icons.verified_rounded,
                  color: context.colors.success,
                  size: 26,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: context.colors.surfaceVariant,
              color: allDone ? context.colors.success : context.colors.primary,
            ),
          ),
          if (!allDone) ...[
            const SizedBox(height: 12),
            Text(
              'Berikutnya: ${next!.number.toString().padLeft(2, '0')} ${next!.label}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: BouncingButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push(next!.route);
                },
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push(next!.route);
                  },
                  child: Text(next!.cta),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumStepTile extends StatelessWidget {
  const _NumStepTile({required this.step, required this.isLast});

  final _DayStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(step.route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: step.done
                        ? context.colors.success.withValues(alpha: 0.12)
                        : context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: step.done
                      ? Icon(
                          Icons.check_rounded,
                          color: context.colors.success,
                          size: 20,
                        )
                      : Text(
                          step.number.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 62, color: context.colors.border),
      ],
    );
  }
}

// ── Masalah ──────────────────────────────────────────────────────────────────

class _MasalahSection extends StatelessWidget {
  const _MasalahSection({required this.checklists});

  final List<ArmadaChecklist> checklists;

  @override
  Widget build(BuildContext context) {
    final bermasalah = checklists
        .where((c) => unitChecklistStatus(c) == ChecklistUnitStatus.bermasalah)
        .toList();
    if (bermasalah.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colors.warning.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: context.colors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Perlu Perhatian',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final c in bermasalah)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${c.platNomor}: ${c.itemBermasalah?.isNotEmpty == true ? c.itemBermasalah : 'ada kondisi tidak baik'}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: () => context.push('/armada/checklist'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.warning,
                  side: BorderSide(
                    color: context.colors.warning.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text('Periksa checklist'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ringkasan Kerja ──────────────────────────────────────────────────────────

class _RingkasanKerja extends StatelessWidget {
  const _RingkasanKerja({required this.armada, required this.ritItems});

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
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
                    color: context.colors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ringkasan Kerja',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: armada.isAlatBerat
                          ? 'Jam Kerja'
                          : 'Muatan Hari Ini (Rit)',
                      value: armada.isAlatBerat
                          ? fmtRitase(ritCount, 'jam')
                          : fmtRitase(ritCount),
                      color: context.colors.primary,
                    ),
                  ),
                  if (armada.isKendaraan) ...[
                    SizedBox(width: 10),
                    Expanded(
                      child: _StatBox(
                        label: 'Estimasi Pendapatan',
                        value: fmtRp(totalUpah),
                        color: context.colors.success,
                      ),
                    ),
                  ],
                ],
              ),
              if (armada.isKendaraan) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: BouncingButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/armada/ritase-input');
                    },
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/armada/ritase-input');
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Input Muatan Baru'),
                    ),
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
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aksi Cepat',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _ShortcutTile(
            icon: Icons.build_outlined,
            title: 'Ajukan Servis',
            subtitle: 'Laporkan kerusakan unit',
            onTap: () =>
                context.push('/armada/servis/ajuan?armadaId=${armada.id}'),
          ),
          _ShortcutTile(
            icon: Icons.history_rounded,
            title: 'Riwayat Servis',
            subtitle: 'Riwayat perbaikan unit',
            onTap: () => context.push('/armada/servis'),
          ),
          if (armada.helperAktifCount > 0)
            _ShortcutTile(
              icon: Icons.badge_outlined,
              title: 'Presensi Pendamping',
              subtitle: 'Catat kehadiran rekan kerja Anda',
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/armada/helper-presensi');
              },
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
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: context.colors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.colors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _labelJenis(String jenis) => labelJenisArmada(jenis);

// ── Banner Dokumen Berkala (TD-C2) ──────────────────────────────────────────

class _DokumenBerkalaBanner extends StatelessWidget {
  const _DokumenBerkalaBanner({required this.dokumenList});

  final List<DokumenBerkalaItem> dokumenList;

  @override
  Widget build(BuildContext context) {
    if (dokumenList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.assignment_late_outlined,
                  color: context.colors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pajak/STNK/KIR Jatuh Tempo ≤ 30 Hari',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final doc in dokumenList)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.colors.warning,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${doc.jenis}${doc.nomor != null ? ' (${doc.nomor})' : ''}: '
                        '${doc.sisaHari != null && doc.sisaHari! < 0 ? 'Sudah lewat tempo (${doc.sisaHari!.abs()} hari lalu)' : 'Sisa ${doc.sisaHari ?? 0} hari'}'
                        '${doc.jatuhTempo != null ? ' (jatuh tempo ${doc.jatuhTempo})' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Pengelolaan dokumen berkala dilakukan oleh Keuangan/Admin via web.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: context.colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
