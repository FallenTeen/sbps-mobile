import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/date_grouping.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/rich_list_tile.dart';
import '../../shared/widgets/searchable_list_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

/// Riwayat mutasi stok (GET /inventory/mutasi) — replacement untuk SnackBar
/// placeholder di InventoryHomeScreen. Filter multi-dimensi (kategori barang,
/// tipe masuk/keluar, rentang tanggal), pencarian, pengelompokan tanggal, dan
/// pagination (load more saat mendekati akhir list).
class InventoryRiwayatScreen extends ConsumerStatefulWidget {
  const InventoryRiwayatScreen({super.key});

  @override
  ConsumerState<InventoryRiwayatScreen> createState() =>
      _InventoryRiwayatScreenState();
}

class _InventoryRiwayatScreenState
    extends ConsumerState<InventoryRiwayatScreen> {
  final _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(inventoryMutasiProvider.notifier).loadMore();
    }
  }

  void _setFilter(InventoryMutasiFilter filter) {
    ref.read(inventoryMutasiFilterProvider.notifier).set(filter);
  }

  Future<void> _pickDateRange() async {
    final current = ref.read(inventoryMutasiFilterProvider);
    final now = DateTime.now();
    final resolved = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          current.tanggalMulai != null && current.tanggalAkhir != null
          ? DateTimeRange(
              start: current.tanggalMulai!,
              end: current.tanggalAkhir!,
            )
          : null,
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
    );
    if (resolved == null || !mounted) return;
    _setFilter(
      InventoryMutasiFilter(
        tipe: current.tipe,
        kategori: current.kategori,
        tanggalMulai: resolved.start,
        tanggalAkhir: resolved.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryMutasiProvider);
    final filter = ref.watch(inventoryMutasiFilterProvider);
    final stokAsync = ref.watch(inventoryStokProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Riwayat Inventory'),
        actions: [
          const PortalSwitchButton(),
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(inventoryMutasiProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(stokAsync),
          const Divider(height: 1),
          Expanded(child: _buildList(state, filter)),
        ],
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<InventoryItem>> stokAsync) {
    final filter = ref.read(inventoryMutasiFilterProvider);
    final categories = stokAsync.value?.map((e) => e.kategori) ??
        const <String>['Bahan Baku', 'Sparepart'];
    final kategoriList = <String>{'Semua', ...categories}.toList()..sort();

    return SearchableListHeader(
      hintText: 'Cari barang...',
      onChanged: (v) => setState(() => _searchQuery = v),
      collapsible: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Semua'),
                selected: filter.tipe == null,
                onSelected: (_) => _setFilter(
                  InventoryMutasiFilter(
                    kategori: filter.kategori,
                    tanggalMulai: filter.tanggalMulai,
                    tanggalAkhir: filter.tanggalAkhir,
                  ),
                ),
              ),
              ChoiceChip(
                label: const Text('Masuk'),
                selected: filter.tipe == MutasiTipe.masuk,
                onSelected: (_) => _setFilter(
                  InventoryMutasiFilter(
                    tipe: MutasiTipe.masuk,
                    kategori: filter.kategori,
                    tanggalMulai: filter.tanggalMulai,
                    tanggalAkhir: filter.tanggalAkhir,
                  ),
                ),
              ),
              ChoiceChip(
                label: const Text('Keluar'),
                selected: filter.tipe == MutasiTipe.keluar,
                onSelected: (_) => _setFilter(
                  InventoryMutasiFilter(
                    tipe: MutasiTipe.keluar,
                    kategori: filter.kategori,
                    tanggalMulai: filter.tanggalMulai,
                    tanggalAkhir: filter.tanggalAkhir,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: filter.kategori ?? 'Semua',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kategori barang'),
            items: kategoriList
                .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                .toList(),
            onChanged: (v) => _setFilter(
              InventoryMutasiFilter(
                tipe: filter.tipe,
                kategori: v == null || v == 'Semua' ? null : v,
                tanggalMulai: filter.tanggalMulai,
                tanggalAkhir: filter.tanggalAkhir,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  avatar:
                      const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(_dateRangeLabel(filter)),
                  onPressed: _pickDateRange,
                ),
                if (filter.tanggalMulai != null || filter.tanggalAkhir != null)
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Hapus tanggal'),
                    onPressed: () => _setFilter(
                      InventoryMutasiFilter(
                        tipe: filter.tipe,
                        kategori: filter.kategori,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateRangeLabel(InventoryMutasiFilter filter) {
    if (filter.tanggalMulai != null && filter.tanggalAkhir != null) {
      return '${fmtTanggal(filter.tanggalMulai)} – ${fmtTanggal(filter.tanggalAkhir)}';
    }
    return 'Pilih rentang tanggal';
  }

  Widget _buildList(InventoryMutasiState state, InventoryMutasiFilter filter) {
    final q = _searchQuery.toLowerCase();
    final searched = q.isEmpty
        ? state.items
        : state.items
              .where(
                (m) =>
                    m.namaBarang.toLowerCase().contains(q) ||
                    m.kategori.toLowerCase().contains(q),
              )
              .toList();

    if (state.loading && state.items.isEmpty && state.error == null) {
      return const SkeletonListView(itemCount: 8);
    }
    if (state.error != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Riwayat',
            subtitle: state.error,
            actionLabel: 'Coba Lagi',
            onAction: () => ref.read(inventoryMutasiProvider.notifier).refresh(),
          ),
        ],
      );
    }
    if (searched.isEmpty) {
      final noData = state.items.isEmpty;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: noData
                ? Icons.history_rounded
                : Icons.search_off_outlined,
            title: noData ? 'Belum Ada Riwayat Mutasi' : 'Tidak Ada Hasil',
            subtitle: noData
                ? 'Mutasi masuk/keluar stok akan tercatat di sini.\nUbah filter untuk melihat rentang lain.'
                : 'Tidak ditemukan barang yang cocok dengan "$_searchQuery".',
            actionLabel: noData ? 'Coba Lagi' : null,
            onAction: noData
                ? () => ref.read(inventoryMutasiProvider.notifier).refresh()
                : null,
          ),
        ],
      );
    }
    if (filter.tipe != null && searched.every((m) => m.tipe != filter.tipe)) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'Tidak Ada Mutasi ${filter.tipe!.label}',
            subtitle: 'Ubah filter tipe atau rentang tanggal.',
          ),
        ],
      );
    }

    final rows = _buildRows(searched);
    return RefreshIndicator(
      onRefresh: () => ref.read(inventoryMutasiProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: rows.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= rows.length) return _buildLoadMoreFooter(state);
          final row = rows[i];
          if (row is _HeaderRow) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
              child: Text(
                row.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.textTertiary,
                ),
              ),
            );
          }
          final mutasi = (row as _MutasiRow).mutasi;
          return StaggeredEntrance(
            index: i,
            child: _MutasiTile(mutasi: mutasi),
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreFooter(InventoryMutasiState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: state.loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                'Menampilkan ${state.items.length} dari ${state.total}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
              ),
      ),
    );
  }

  /// Susun baris dengan header pengelompokan tanggal (pola NotifikasiScreen).
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