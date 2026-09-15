import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/adaptive_master_detail.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'inventory_detail_stok_screen.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class InventoryStokScreen extends ConsumerStatefulWidget {
  const InventoryStokScreen({super.key, this.initialSelectedId});

  /// Id awal dari query `?selected=` (deep-link, mode Expanded).
  final String? initialSelectedId;

  @override
  ConsumerState<InventoryStokScreen> createState() =>
      _InventoryStokScreenState();
}

class _InventoryStokScreenState extends ConsumerState<InventoryStokScreen> {
  final _searchController = TextEditingController();
  String _selectedKategori = 'Semua';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _kategoriList(List<InventoryItem> items) {
    final kategori = items.map((e) => e.kategori).toSet().toList();
    return ['Semua', ...kategori]..sort();
  }

  List<InventoryItem> _filteredItems(List<InventoryItem> items) {
    return items.where((item) {
      final matchSearch =
          _searchQuery.isEmpty ||
          item.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.kategori.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchKategori =
          _selectedKategori == 'Semua' || item.kategori == _selectedKategori;
      return matchSearch && matchKategori;
    }).toList();
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
    final filtered = _filteredItems(items);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedKategori,
            items: categories
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
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
        Expanded(
          child: filtered.isEmpty
              ? AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Tidak ada barang ditemukan',
                  subtitle: 'Coba ubah filter atau kata kunci pencarian',
                )
              : ListView.builder(
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
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rendah
              ? context.colors.error.withValues(alpha: 0.3)
              : context.colors.border,
        ),
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
                      Text(
                        item.kategori,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
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
