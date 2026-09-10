import 'package:flutter/material.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'inventory_models.dart';

class InventoryStokScreen extends StatefulWidget {
  const InventoryStokScreen({super.key});

  @override
  State<InventoryStokScreen> createState() => _InventoryStokScreenState();
}

class _InventoryStokScreenState extends State<InventoryStokScreen> {
  final _searchController = TextEditingController();
  String _selectedKategori = 'Semua';
  String _searchQuery = '';

  final List<InventoryItem> _mockItems = [
    InventoryItem(
      id: 'inv-001',
      nama: 'Oli Mesin 15W-40',
      kategori: 'Pelumas',
      stokSaatIni: 24,
      stokMinimum: 10,
      satuan: 'Liter',
      lokasiGudang: 'Gudang A',
    ),
    InventoryItem(
      id: 'inv-002',
      nama: 'Filter Udara HD-700',
      kategori: 'Filter',
      stokSaatIni: 3,
      stokMinimum: 5,
      satuan: 'Pcs',
      lokasiGudang: 'Gudang A',
    ),
    InventoryItem(
      id: 'inv-003',
      nama: 'Kampas Rem Depan',
      kategori: 'Rem',
      stokSaatIni: 8,
      stokMinimum: 4,
      satuan: 'Set',
      lokasiGudang: 'Gudang B',
    ),
    InventoryItem(
      id: 'inv-004',
      nama: 'Bearing Roda Depan',
      kategori: 'Suku Cadang',
      stokSaatIni: 2,
      stokMinimum: 4,
      satuan: 'Pcs',
      lokasiGudang: 'Gudang B',
    ),
    InventoryItem(
      id: 'inv-005',
      nama: 'Belt Alternator',
      kategori: 'Belt',
      stokSaatIni: 6,
      stokMinimum: 3,
      satuan: 'Pcs',
      lokasiGudang: 'Gudang A',
    ),
    InventoryItem(
      id: 'inv-006',
      nama: 'Minyak Rem DOT-4',
      kategori: 'Pelumas',
      stokSaatIni: 1,
      stokMinimum: 5,
      satuan: 'Liter',
      lokasiGudang: 'Gudang A',
    ),
    InventoryItem(
      id: 'inv-007',
      nama: 'V-Belt AC',
      kategori: 'Belt',
      stokSaatIni: 4,
      stokMinimum: 2,
      satuan: 'Pcs',
      lokasiGudang: 'Gudang A',
    ),
    InventoryItem(
      id: 'inv-008',
      nama: 'Lampu Depan LED',
      kategori: 'Kelistrikan',
      stokSaatIni: 0,
      stokMinimum: 2,
      satuan: 'Pcs',
      lokasiGudang: 'Gudang B',
    ),
  ];

  List<String> get _kategoriList {
    final kategori =
        _mockItems.map((e) => e.kategori).toSet().toList();
    return ['Semua', ...kategori]..sort();
  }

  List<InventoryItem> get _filteredItems {
    return _mockItems.where((item) {
      final matchSearch = _searchQuery.isEmpty ||
          item.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.kategori.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchKategori =
          _selectedKategori == 'Semua' || item.kategori == _selectedKategori;
      return matchSearch && matchKategori;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Daftar Stok'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedKategori,
              items: _kategoriList
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedKategori = v);
              },
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Tidak ada barang ditemukan',
                    subtitle: 'Coba ubah filter atau kata kunci pencarian',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _StokItemCard(item: item);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StokItemCard extends StatelessWidget {
  const _StokItemCard({required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context) {
    final rendah = item.isStokRendah;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rendah
              ? AppTheme.errorColor.withValues(alpha: 0.3)
              : AppTheme.borderColor,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Detail ${item.nama} — segera hadir'),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: rendah
                        ? AppTheme.errorColor.withValues(alpha: 0.08)
                        : AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    rendah
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    size: 20,
                    color: rendah ? AppTheme.errorColor : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.kategori,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
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
                        color: rendah ? AppTheme.errorColor : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '/ ${item.stokMinimum} ${item.satuan}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
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
