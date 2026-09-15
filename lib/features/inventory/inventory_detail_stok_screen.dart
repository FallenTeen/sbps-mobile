import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/date_grouping.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/rich_list_tile.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_pill.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

/// Detail satu barang stok: info item + riwayat mutasi barang tersebut
/// (layer full-page ketika Compact/Medium — pengganti SnackBar placeholder).
class InventoryDetailStokScreen extends ConsumerWidget {
  const InventoryDetailStokScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(inventoryStokProvider).value
        ?.where((i) => i.id == itemId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: BreadcrumbTitle(
          parentLabel: 'Daftar Stok',
          title: 'Detail Barang · ${item?.nama ?? '…'}',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: InventoryDetailStokContent(itemId: itemId),
    );
  }
}

/// Konten detail stok tanpa Scaffold/AppBar — dipakai sebagai body full-page
/// maupun panel kanan [AdaptiveMasterDetail] saat Expanded.
class InventoryDetailStokContent extends ConsumerStatefulWidget {
  const InventoryDetailStokContent({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<InventoryDetailStokContent> createState() =>
      _InventoryDetailStokContentState();
}

class _InventoryDetailStokContentState
    extends ConsumerState<InventoryDetailStokContent> {
  MutasiTipe? _tipeFilter;

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(inventoryStokProvider);
    final mutasiAsync = ref.watch(
      inventoryMaterialMutasiProvider(widget.itemId),
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(inventoryStokProvider);
        ref.invalidate(inventoryMaterialMutasiProvider(widget.itemId));
      },
      child: itemAsync.when(
        loading: () => const SkeletonDetailView(),
        error: (e, _) => _errorList(e),
        data: (items) {
          final item = items.where((i) => i.id == widget.itemId).firstOrNull;
          if (item == null) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Barang tidak ditemukan',
                  subtitle: 'Barang ini mungkin tidak lagi aktif.',
                ),
              ],
            );
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              StaggeredEntrance(
                index: 0,
                child: _ItemHeader(item: item),
              ),
              const SizedBox(height: 16),
              StaggeredEntrance(
                index: 1,
                child: _MutasiSection(
                  item: item,
                  async: mutasiAsync,
                  tipeFilter: _tipeFilter,
                  onTipeChanged: (t) => setState(() => _tipeFilter = t),
                  onRefresh: () => ref
                      .invalidate(
                        inventoryMaterialMutasiProvider(widget.itemId),
                      ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _errorList(Object e) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal Memuat Detail Stok',
          subtitle: e is ApiException ? e.message : 'Gagal memuat detail stok.',
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(inventoryStokProvider),
        ),
      ],
    );
  }
}

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final rendah = item.isStokRendah;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rendah
              ? context.colors.error.withValues(alpha: 0.35)
              : context.colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nama,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.kategori,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: rendah ? 'Stok Rendah' : 'Stok Aman',
                color: rendah ? context.colors.error : context.colors.success,
                icon: rendah
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                filled: rendah,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatMini(
                label: 'Stok Saat Ini',
                value: '${item.stokSaatIni}',
                color: rendah
                    ? context.colors.error
                    : context.colors.textPrimary,
              ),
              const SizedBox(width: 12),
              _StatMini(
                label: 'Stok Minimum',
                value: '${item.stokMinimum} ${item.satuan}',
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
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
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MutasiSection extends StatelessWidget {
  const _MutasiSection({
    required this.item,
    required this.async,
    required this.tipeFilter,
    required this.onTipeChanged,
    required this.onRefresh,
  });

  final InventoryItem item;
  final AsyncValue<StokMutasiPage> async;
  final MutasiTipe? tipeFilter;
  final ValueChanged<MutasiTipe?> onTipeChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, size: 20, color: context.colors.primary),
            const SizedBox(width: 8),
            Text(
              'Riwayat Mutasi Barang Ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Semua'),
              selected: tipeFilter == null,
              onSelected: (_) => onTipeChanged(null),
            ),
            ChoiceChip(
              label: const Text('Masuk'),
              selected: tipeFilter == MutasiTipe.masuk,
              onSelected: (_) => onTipeChanged(MutasiTipe.masuk),
            ),
            ChoiceChip(
              label: const Text('Keluar'),
              selected: tipeFilter == MutasiTipe.keluar,
              onSelected: (_) => onTipeChanged(MutasiTipe.keluar),
            ),
          ],
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const SkeletonLoader(
            child: Column(
              children: [
                SkeletonBlock(height: 76, borderRadius: 14),
                SizedBox(height: 8),
                SkeletonBlock(height: 76, borderRadius: 14),
              ],
            ),
          ),
          error: (e, _) => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Mutasi',
            subtitle: e is ApiException ? e.message : 'Gagal memuat mutasi.',
            actionLabel: 'Coba Lagi',
            onAction: onRefresh,
          ),
          data: (page) {
            final items = page.items.where((m) {
              if (tipeFilter != null && m.tipe != tipeFilter) return false;
              return true;
            }).toList();
            if (items.isEmpty) {
              return AppEmptyState(
                icon: Icons.history_rounded,
                title: 'Belum Ada Mutasi',
                subtitle: tipeFilter != null
                    ? 'Tidak ada mutasi ${tipeFilter!.label.toLowerCase()} untuk barang ini.'
                    : 'Mutasi masuk/keluar barang ini belum tercatat.',
              );
            }
            final rows = _buildRows(items);
            return Column(
              children: [
                for (final row in rows)
                  if (row is _HeaderRow)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          row.label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: context.colors.textTertiary,
                              ),
                        ),
                      ),
                    )
                  else
                    _MutasiTile(
                      mutasi: (row as _MutasiRow).mutasi,
                    ),
                if (page.hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Menampilkan ${page.items.length} dari ${page.total} mutasi — riwayat lebih lengkap di layar Riwayat.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Object> _buildRows(List<StokMutasi> items) {
    final rows = <Object>[];
    String? lastHeader;
    for (final m in items) {
      final header = dateGroupLabel(m.createdAt);
      if (header != lastHeader) {
        rows.add(_HeaderRow(header));
        lastHeader = header;
      }
      rows.add(_MutasiRow(m));
    }
    return rows;
  }
}

class _HeaderRow {
  const _HeaderRow(this.label);
  final String label;
}

class _MutasiRow {
  const _MutasiRow(this.mutasi);
  final StokMutasi mutasi;
}

class _MutasiTile extends StatelessWidget {
  const _MutasiTile({required this.mutasi});

  final StokMutasi mutasi;

  @override
  Widget build(BuildContext context) {
    final masuk = mutasi.tipe == MutasiTipe.masuk;
    final color = masuk
        ? context.colors.chartPositive
        : context.colors.chartNegative;
    final jumlahLabel = mutasi.jumlah % 1 == 0
        ? mutasi.jumlah.toInt().toString()
        : mutasi.jumlah.toStringAsFixed(2);

    return RichListTile(
      title: mutasi.namaBarang,
      subtitle:
          '${mutasi.tipe.label} $jumlahLabel ${mutasi.satuan} · via ${mutasi.sumber.label}',
      meta: mutasi.createdBy,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          masuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          size: 20,
          color: color,
        ),
      ),
      trailing: Text(
        fmtTanggalWaktu(mutasi.createdAt),
        style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
      ),
    );
  }
}