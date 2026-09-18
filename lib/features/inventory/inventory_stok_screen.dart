import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/adaptive_master_detail.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/status_pill.dart';
import 'inventory_detail_stok_screen.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';
import 'inventory_rules.dart' as rules;

class InventoryStokScreen extends ConsumerStatefulWidget {
  const InventoryStokScreen({
    super.key,
    this.initialSelectedId,
    this.initialRendah = false,
  });

  final String? initialSelectedId;
  final bool initialRendah;

  @override
  ConsumerState<InventoryStokScreen> createState() =>
      _InventoryStokScreenState();
}

class _InventoryStokScreenState extends ConsumerState<InventoryStokScreen> {
  final _searchController = TextEditingController();
  String _selectedKategori = 'Semua';
  String _searchQuery = '';
  bool _hanyaRendah = false;
  bool _rendahDulu = true;

  @override
  void initState() {
    super.initState();
    _hanyaRendah = widget.initialRendah;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _kategoriList(List<InventoryItem> items) {
    final kategori = items.map((e) => e.kategori).toSet().toList();
    return ['Semua', ...kategori]..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Daftar Stok'),
        actions: [PortalSwitchButton()],
      ),
      body: AdaptiveMasterDetail(
        initialSelectedId: widget.initialSelectedId,
        pushRouteFor: (id) => '/inventory/stok/$id',
        emptyDetailPlaceholder: const MasterDetailEmptyPlaceholder(
          icon: Icons.inventory_2_outlined,
          title: 'Pilih barang',
          subtitle: 'Detail stok & riwayat mutasi akan tampil di panel ini',
        ),
        detailBuilder: (context, selectedId) =>
            InventoryDetailStokContent(itemId: selectedId),
        masterBuilder: (context, selectedId, onSelect) => ResponsiveCenter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Cari barang...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Hapus pencarian',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildBody(context, selectedId, onSelect),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String? selectedId,
    void Function(String id) onSelect,
  ) {
    final async = ref.watch(inventoryStokProvider);
    return async.when(
      loading: () => const SkeletonLoader(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SkeletonBlock(height: 66, borderRadius: 14),
              SizedBox(height: 8),
              SkeletonBlock(height: 66, borderRadius: 14),
              SizedBox(height: 8),
              SkeletonBlock(height: 66, borderRadius: 14),
            ],
          ),
        ),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: context.colors.error,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat daftar stok.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(inventoryStokProvider),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Tidak ada data stok',
            subtitle: 'Belum ada bahan baku atau sparepart',
          );
        }
        return _buildList(items, selectedId ?? '', onSelect);
      },
    );
  }

  Widget _buildList(
    List<InventoryItem> items,
    String selectedId,
    void Function(String id) onSelect,
  ) {
    final categories = _kategoriList(items);
    final filtered = rules.filterStok(
      items,
      query: _searchQuery,
      kategori: _selectedKategori == 'Semua' ? null : _selectedKategori,
      hanyaRendah: _hanyaRendah,
      rendahDulu: _rendahDulu,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedKategori,
                  items: categories
                      .map(
                        (k) => DropdownMenuItem(value: k, child: Text(k)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedKategori = v);
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Rendah',
                selected: _hanyaRendah,
                color: context.colors.error,
                onTap: () => setState(() => _hanyaRendah = !_hanyaRendah),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: '↑ Rendah',
                selected: _rendahDulu,
                color: context.colors.warning,
                onTap: () => setState(() => _rendahDulu = !_rendahDulu),
              ),
            ],
          ),
        ),
        if (filtered.isEmpty)
          Expanded(
            child: AppEmptyState(
              icon: _hanyaRendah
                  ? Icons.check_circle_outline_rounded
                  : Icons.search_off_rounded,
              title: _hanyaRendah
                  ? 'Semua Stok Aman'
                  : 'Tidak ada barang ditemukan',
              subtitle: _hanyaRendah
                  ? 'Tidak ada item di bawah stok minimum.'
                  : 'Coba ubah filter atau kata kunci pencarian',
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _StokItemCard(
                  item: item,
                  selected: item.id == selectedId,
                  onTap: () => onSelect(item.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : context.colors.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.4)
                  : context.colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? color : context.colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StokItemCard extends StatelessWidget {
  const _StokItemCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final InventoryItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rendah = item.isStokRendah;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? context.colors.primary
              : rendah
                  ? context.colors.error.withValues(alpha: 0.3)
                  : context.colors.border,
          width: selected ? 2 : 1,
        ),
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
                    color: rendah
                        ? context.colors.error.withValues(alpha: 0.08)
                        : context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    rendah
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    size: 20,
                    color: rendah
                        ? context.colors.error
                        : context.colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.kategori,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.textTertiary,
                            ),
                          ),
                          if (item.lokasiGudang != null &&
                              item.lokasiGudang!.isNotEmpty) ...[
                            Text(
                              ' \u2022 ',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textTertiary,
                              ),
                            ),
                            Icon(
                              Icons.place_outlined,
                              size: 11,
                              color: context.colors.textTertiary,
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                item.lokasiGudang!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colors.textTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      StatusPill(
                        label: rendah ? 'Stok Rendah' : 'Stok Aman',
                        color: rendah
                            ? context.colors.error
                            : context.colors.success,
                        icon: rendah
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        filled: rendah,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.stokSaatIni}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: rendah
                            ? context.colors.error
                            : context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      '/ ${item.stokMinimum} ${item.satuan}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
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
