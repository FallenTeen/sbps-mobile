import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/adaptive_master_detail.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/searchable_list_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'detail_qc_screen.dart';
import 'models/qc_sample.dart';
import 'qc_providers.dart';
import 'status_badge.dart';

/// Riwayat QC: search + filter status, badge warna per status, pagination
/// tombol "Muat lagi" (Fase A2.5).
class RiwayatQcScreen extends ConsumerStatefulWidget {
  const RiwayatQcScreen({super.key, this.initialSelectedId});

  /// Id awal dari query `?selected=` (deep-link, mode Expanded).
  final String? initialSelectedId;

  @override
  ConsumerState<RiwayatQcScreen> createState() => _RiwayatQcScreenState();
}

class _RiwayatQcScreenState extends ConsumerState<RiwayatQcScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(qcRiwayatProvider);
    final filter = ref.watch(qcRiwayatFilterProvider);

    final q = _searchQuery.toLowerCase();
    final items = q.isEmpty
        ? state.items
        : state.items
              .where(
                (s) =>
                    (s.produkNama ?? '').toLowerCase().contains(q) ||
                    (s.mesinNama ?? '').toLowerCase().contains(q) ||
                    (s.titikNama ?? '').toLowerCase().contains(q) ||
                    (s.operatorNama ?? '').toLowerCase().contains(q),
              )
              .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat QC'),
        actions: const [PortalSwitchButton()],
      ),
      body: AdaptiveMasterDetail(
        initialSelectedId: widget.initialSelectedId,
        pushRouteFor: (id) => '/qc/riwayat/detail/$id',
        emptyDetailPlaceholder: const MasterDetailEmptyPlaceholder(
          icon: Icons.science_outlined,
          title: 'Pilih hasil pengujian',
          subtitle: 'Detail sampel QC akan tampil di panel ini',
        ),
        masterBuilder: (context, selectedId, onSelect) => ResponsiveCenter(
          child: Column(
            children: [
              SearchableListHeader(
                hintText: 'Cari sampel...',
                onChanged: (v) => setState(() => _searchQuery = v),
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final (label, value) in [
                        ('Semua status', null),
                        for (final s in kQcStatuses) (qcStatusLabel(s), s),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -2,
                              vertical: -2,
                            ),
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            selected: filter.status == value,
                            selectedColor: context.colors.primary.withValues(
                              alpha: 0.15,
                            ),
                            checkmarkColor: context.colors.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: filter.status == value
                                  ? context.colors.primary
                                  : context.colors.textSecondary,
                            ),
                            onSelected: (_) => ref
                                .read(qcRiwayatFilterProvider.notifier)
                                .set(QcRiwayatFilter(status: value)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(qcRiwayatProvider.notifier).refresh(),
                  child: _buildList(
                    context,
                    ref,
                    state,
                    items,
                    selectedId,
                    onSelect,
                  ),
                ),
              ),
            ],
          ),
        ),
        detailBuilder: (context, selectedId) =>
            DetailQcContent(sampleId: selectedId),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    QcRiwayatState state,
    List<QcSample> items,
    String? selectedId,
    void Function(String id) onSelect,
  ) {
    if (state.loading && state.items.isEmpty && state.error == null) {
      return const SkeletonListView(itemCount: 5);
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Data QC',
            subtitle: state.error,
            actionLabel: 'Coba Lagi',
            onAction: () => ref.read(qcRiwayatProvider.notifier).refresh(),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: _searchQuery.isNotEmpty
                ? Icons.search_off_outlined
                : Icons.science_outlined,
            title: _searchQuery.isNotEmpty
                ? 'Tidak Ada Hasil Pencarian'
                : 'Belum Ada Data QC',
            subtitle: _searchQuery.isNotEmpty
                ? 'Tidak ditemukan data yang cocok dengan "$_searchQuery".'
                : 'Belum ada data pengujian sampel untuk filter status ini.',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: FilledButton.tonal(
                onPressed: state.loading
                    ? null
                    : () => ref.read(qcRiwayatProvider.notifier).loadMore(),
                child: Text(state.loading ? 'Memuat...' : 'Muat lagi'),
              ),
            ),
          );
        }
        final s = items[i];
        return StaggeredEntrance(
          index: i,
          child: Card(
            child: ListTile(
              tileColor: selectedId == s.id
                  ? context.colors.primary.withValues(alpha: 0.06)
                  : null,
              title: Text(
                '${s.produkNama ?? 'Produk'} — ${s.mesinNama ?? 'Mesin'}',
              ),
              subtitle: Text(
                'Slump ${_fmt(s.nilaiSlump)}'
                '${s.hasilUjiTekan != null ? ' • Uji tekan ${_fmt(s.hasilUjiTekan)} MPa' : ''}\n'
                '${s.titikNama ?? '-'}'
                '${s.createdAt != null ? ' • ${fmtTanggalWaktu(s.createdAt!)}' : ''}',
              ),
              isThreeLine: true,
              trailing: QcStatusBadge(status: s.status),
              onTap: () => onSelect(s.id),
            ),
          ),
        );
      },
    );
  }
}

String _fmt(double? n) => n == null
    ? '-'
    : n % 1 == 0
    ? n.toInt().toString()
    : n.toStringAsFixed(1);
