import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'armada_providers.dart';
import 'models/armada.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../core/formatters.dart';

/// Riwayat ritase dengan tab "Hari Ini" dan "Riwayat".
/// Tab Hari Ini: ringkasan ritase hari ini per kendaraan + tombol input baru.
/// Tab Riwayat: daftar ritase lengkap dengan pagination.
class RiwayatRitaseScreen extends ConsumerStatefulWidget {
  const RiwayatRitaseScreen({super.key});

  @override
  ConsumerState<RiwayatRitaseScreen> createState() =>
      _RiwayatRitaseScreenState();
}

class _RiwayatRitaseScreenState extends ConsumerState<RiwayatRitaseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Muatan'),
        actions: [PortalSwitchButton()],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hari Ini'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_HariIniTab(), _RiwayatTab()],
      ),
    );
  }
}

/// Tab "Hari Ini": ringkasan ritase hari ini per kendaraan.
class _HariIniTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armadaAsync = ref.watch(armadaSayaProvider);

    return armadaAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) => AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Gagal memuat data',
        subtitle: friendlyErrorMessage(e),
        actionLabel: 'Coba lagi',
        onAction: () => ref.invalidate(armadaSayaProvider),
      ),
      data: (armadaList) {
        if (armadaList.isEmpty) {
          return const AppEmptyState(
            icon: Icons.route_outlined,
            title: 'Tidak ada armada',
            subtitle: 'Anda belum memiliki armada yang ditugaskan.',
          );
        }

        return Column(
          children: [
            // Summary card
            Container(
              padding: EdgeInsets.all(16),
              color: context.colors.primary.withValues(alpha: 0.05),
              child: Row(
                children: [
                  Icon(Icons.today, color: context.colors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ritase Hari Ini',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        Text(
                          '${armadaList.length} kendaraan aktif',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textTertiary,
                          ),
                        ),
                        if (armadaList.length == 1) ...[
                          SizedBox(height: 4),
                          Text(
                            armadaList.first.isAlatBerat
                                ? (armadaList.first.jamOperasionalTerkini !=
                                          null
                                      ? 'HM: ${armadaList.first.jamOperasionalTerkini} jam'
                                      : 'HM: -')
                                : (armadaList.first.odoTerkini != null
                                      ? 'ODO: ${armadaList.first.odoTerkini} km'
                                      : 'ODO: -'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Armada list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: armadaList.length,
                itemBuilder: (context, index) {
                  final armada = armadaList[index];
                  return _ArmadaRitaseCard(armada: armada);
                },
              ),
            ),

            // Input button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/armada/ritase-input'),
                  icon: const Icon(Icons.add),
                  label: const Text('Input Muatan Baru'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Card armada di tab Hari Ini.
class _ArmadaRitaseCard extends StatelessWidget {
  const _ArmadaRitaseCard({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.colors.primary.withValues(alpha: 0.1),
          child: Icon(
            Icons.local_shipping,
            color: context.colors.primary,
            size: 20,
          ),
        ),
        title: Text(
          armada.platNomor,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${armada.jenis ?? 'N/A'}${armada.titikNama != null ? ' • ${armada.titikNama}' : ''}',
          style: TextStyle(fontSize: 12, color: context.colors.textTertiary),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Tab "Riwayat": daftar ritase paginated.
class _RiwayatTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ritaseRiwayatProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(ritaseRiwayatProvider.notifier).refresh(),
      child: _buildList(context, ref, state),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    RitaseRiwayatState state,
  ) {
    if (state.loading && state.items.isEmpty && state.error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return AppEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Gagal memuat data',
        subtitle: state.error!,
        actionLabel: 'Coba lagi',
        onAction: () => ref.read(ritaseRiwayatProvider.notifier).refresh(),
      );
    }
    if (state.items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.route_outlined,
        title: 'Belum ada riwayat muatan',
        subtitle: 'Muatan yang sudah Anda catat akan muncul di sini.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= state.items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: FilledButton.tonal(
                onPressed: state.loading
                    ? null
                    : () => ref.read(ritaseRiwayatProvider.notifier).loadMore(),
                child: Text(state.loading ? 'Memuat...' : 'Muat lagi'),
              ),
            ),
          );
        }
        return _RitaseCard(ritase: state.items[i]);
      },
    );
  }
}

class _RitaseCard extends StatelessWidget {
  const _RitaseCard({required this.ritase});

  final RitaseItem ritase;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${ritase.material ?? 'Material'} • ${fmtTanggal(ritase.tanggal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                if (ritase.status != null) _RitaseBadge(status: ritase.status!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${fmtRitase(ritase.jumlahRit)}'
              '${ritase.ruteAsal != null && ritase.ruteTujuan != null ? ' • ${ritase.ruteAsal} → ${ritase.ruteTujuan}' : ''}',
            ),
            if (ritase.jumlahDriver != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.scale_outlined, size: 14, color: context.colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Muatan: ${ritase.jumlahDriver} ${ritase.satuanMuatan ?? 'ton'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (ritase.jumlahVerifikasiLogistik != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• Netto: ${ritase.jumlahVerifikasiLogistik} ton',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            if (ritase.totalUpahRit != null) ...[
              const SizedBox(height: 4),
              Text(
                'Upah: ${fmtRp(ritase.totalUpahRit!)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            // TD-E2: Badge verifikasi ritase (Menunggu, Verified Logistik, Verified Security, Selisih)
            if (ritase.hasVerifikasiData) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (ritase.hasSelisih)
                    _VerifikasiChip(
                      label: 'Selisih',
                      color: context.colors.error,
                      icon: Icons.warning_amber_rounded,
                    ),
                  if (ritase.isVerifiedSecurity)
                    _VerifikasiChip(
                      label: 'Verified (Security)',
                      color: context.colors.success,
                      icon: Icons.shield_outlined,
                    ),
                  if (ritase.isVerifiedLogistik)
                    _VerifikasiChip(
                      label: 'Verified (Logistik)',
                      color: context.colors.info,
                      icon: Icons.verified_outlined,
                    )
                  else if (ritase.isMenungguVerifikasi)
                    _VerifikasiChip(
                      label: 'Menunggu verifikasi',
                      color: context.colors.warning,
                      icon: Icons.hourglass_top_rounded,
                    ),
                  if (ritase.wajibJembatanTimbang == true && !ritase.isVerifiedLogistik)
                    _VerifikasiChip(
                      label: 'Wajib Timbang',
                      color: context.colors.secondary,
                      icon: Icons.scale_rounded,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerifikasiChip extends StatelessWidget {
  const _VerifikasiChip({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RitaseBadge extends StatelessWidget {
  const _RitaseBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'disetujui' => context.colors.success,
      'ditagih' => context.colors.info,
      'draft' => context.colors.warning,
      _ => context.colors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _labelStatus(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _labelStatus(String status) => switch (status) {
  'disetujui' => 'Disetujui',
  'ditagih' => 'Ditagih',
  'draft' => 'Draft',
  _ => status,
};
