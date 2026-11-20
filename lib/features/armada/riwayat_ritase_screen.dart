import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'armada_providers.dart';
import 'models/armada.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/utils/status_labels.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/illustrated_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/status_pill.dart';
import '../../core/formatters.dart';

String ritaseDetailPath(RitaseItem ritase) => '/armada/ritase/${ritase.id}';

String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);

bool _tanggalLocaleReady = false;

String _fmtCardTanggal(dynamic input) {
  if (!_tanggalLocaleReady) {
    initializeDateFormatting('id_ID');
    _tanggalLocaleReady = true;
  }
  return fmtTanggal(input);
}

/// Riwayat ritase dengan tab "Hari Ini" dan "Riwayat".
/// Tab Hari Ini: ringkasan armada + muatan yang dicatat hari ini.
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
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Hari Ini')),
                  ButtonSegment(value: 1, label: Text('Riwayat')),
                ],
                selected: {_tabController.index},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  _tabController.animateTo(selection.first);
                },
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_HariIniTab(), _RiwayatTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab "Hari Ini": ringkasan armada + muatan yang dicatat hari ini.
class _HariIniTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armadaAsync = ref.watch(armadaSayaProvider);
    final hariIni = _todayIso();
    final ritaseAsync = ref.watch(ritaseHariIniProvider(hariIni));

    return Column(
      children: [
        _buildRingkasan(context, ref, armadaAsync),
        Expanded(
          child: ritaseAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Gagal memuat data',
              subtitle: friendlyErrorMessage(e),
              illustrationVariant: EmptyStateVariant.error,
              actionLabel: 'Coba lagi',
              onAction: () => ref.invalidate(ritaseHariIniProvider(hariIni)),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.route_outlined,
                  title: 'Belum ada muatan hari ini',
                  subtitle: 'Muatan yang Anda catat hari ini akan muncul di sini.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = page.items[i];
                  return RitaseListCard(
                    ritase: item,
                    onTap: () => context.push(ritaseDetailPath(item)),
                    onSelesai: () => ref
                        .read(ritaseRiwayatProvider.notifier)
                        .selesaikan(item.id),
                  );
                },
              );
            },
          ),
        ),
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
  }

  Widget _buildRingkasan(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ArmadaSaya>> armadaAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.colors.primary.withValues(alpha: 0.05),
      child: armadaAsync.when(
        loading: () => const SizedBox(
          height: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                color: context.colors.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                friendlyErrorMessage(e),
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(armadaSayaProvider),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
        data: (armadaList) {
          final ringkasan = armadaList.isEmpty
              ? 'Tidak ada armada'
              : '${armadaList.length} kendaraan aktif';
          return Row(
            children: [
              Icon(Icons.today, color: context.colors.primary, size: 20),
              const SizedBox(width: 8),
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
                      ringkasan,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    ),
                    if (armadaList.length == 1) ...[
                      const SizedBox(height: 4),
                      Text(
                        armadaList.first.isAlatBerat
                            ? (armadaList.first.jamOperasionalTerkini != null
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
          );
        },
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
        illustrationVariant: EmptyStateVariant.error,
        actionLabel: 'Coba lagi',
        onAction: () => ref.read(ritaseRiwayatProvider.notifier).refresh(),
      );
    }
    if (state.items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.route_outlined,
        title: 'Belum ada riwayat muatan',
        subtitle: 'Muatan yang sudah Anda catat akan muncul di sini.',
        illustrationVariant: EmptyStateVariant.noData,
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
        final item = state.items[i];
        return RitaseListCard(
          ritase: item,
          onTap: () => context.push(ritaseDetailPath(item)),
          onSelesai: () =>
              ref.read(ritaseRiwayatProvider.notifier).selesaikan(item.id),
        );
      },
    );
  }
}

class RitaseListCard extends StatelessWidget {
  const RitaseListCard({
    super.key,
    required this.ritase,
    required this.onTap,
    this.onSelesai,
  });

  final RitaseItem ritase;
  final VoidCallback onTap;
  final VoidCallback? onSelesai;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Semantics(
              button: true,
              label: 'Lihat timeline ritase ${ritase.id}',
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
                            '${ritase.material ?? 'Material'} • ${_fmtCardTanggal(ritase.tanggal)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (ritase.status != null)
                          StatusPill(
                            label: _labelStatus(ritase.status!),
                            color: statusColor(ritase.status!, context),
                            borderRadius: 999,
                          ),
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
                          Icon(
                            Icons.scale_outlined,
                            size: 14,
                            color: context.colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Muatan: ${ritase.jumlahDriver} ${ritase.satuanMuatan ?? 'ton'}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
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
                    if (ritase.isSelesai || ritase.hasVerifikasiData) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (ritase.isSelesai)
                            StatusPill(
                              label: 'Selesai',
                              color: context.colors.success,
                              icon: Icons.check_circle_outline,
                              borderRadius: 999,
                            ),
                          if (ritase.hasSelisih)
                            StatusPill(
                              label: 'Selisih',
                              color: context.colors.error,
                              icon: Icons.warning_amber_rounded,
                              borderRadius: 999,
                            ),
                          if (ritase.isVerifiedSecurity)
                            StatusPill(
                              label: 'Verified (Security)',
                              color: context.colors.success,
                              icon: Icons.shield_outlined,
                              borderRadius: 999,
                            ),
                          if (ritase.isVerifiedLogistik)
                            StatusPill(
                              label: 'Verified (Logistik)',
                              color: context.colors.info,
                              icon: Icons.verified_outlined,
                              borderRadius: 999,
                            )
                          else if (ritase.isMenungguVerifikasi)
                            StatusPill(
                              label: 'Menunggu verifikasi',
                              color: context.colors.warning,
                              icon: Icons.hourglass_top_rounded,
                              borderRadius: 999,
                            ),
                          if (ritase.wajibJembatanTimbang == true &&
                              !ritase.isVerifiedLogistik)
                            StatusPill(
                              label: 'Wajib Timbang',
                              color: context.colors.secondary,
                              icon: Icons.scale_rounded,
                              borderRadius: 999,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (ritase.bisaSelesaikan)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: FilledButton.tonal(
                onPressed: onSelesai,
                child: const Text('Selesaikan Ritase'),
              ),
            ),
        ],
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
