import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/queue_card.dart';
import 'inventory_models.dart';

class InventoryHomeScreen extends ConsumerStatefulWidget {
  const InventoryHomeScreen({super.key});

  @override
  ConsumerState<InventoryHomeScreen> createState() =>
      _InventoryHomeScreenState();
}

class _InventoryHomeScreenState extends ConsumerState<InventoryHomeScreen> {
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
  ];

  final List<InventoryRequest> _mockRequests = [
    InventoryRequest(
      id: 'req-001',
      workshopJobId: 'wj-001',
      platNomor: 'DK 1234 AB',
      kategoriServis: 'Ganti Oli',
      status: InventoryRequestStatus.pending,
      items: const [
        InventoryRequestItem(
          id: 'ri-001',
          namaBarang: 'Oli Mesin 15W-40',
          jumlahDiminta: 8,
          jumlahTersedia: 24,
          satuan: 'Liter',
          status: InventoryRequestItemStatus.tersedia,
        ),
        InventoryRequestItem(
          id: 'ri-002',
          namaBarang: 'Filter Udara HD-700',
          jumlahDiminta: 1,
          jumlahTersedia: 3,
          satuan: 'Pcs',
          status: InventoryRequestItemStatus.tersedia,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    InventoryRequest(
      id: 'req-002',
      workshopJobId: 'wj-002',
      platNomor: 'DK 5678 CD',
      kategoriServis: 'Servis Rem',
      status: InventoryRequestStatus.pending,
      items: const [
        InventoryRequestItem(
          id: 'ri-003',
          namaBarang: 'Kampas Rem Depan',
          jumlahDiminta: 2,
          jumlahTersedia: 8,
          satuan: 'Set',
          status: InventoryRequestItemStatus.tersedia,
        ),
        InventoryRequestItem(
          id: 'ri-004',
          namaBarang: 'Minyak Rem DOT-4',
          jumlahDiminta: 3,
          jumlahTersedia: 1,
          satuan: 'Liter',
          status: InventoryRequestItemStatus.kurang,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    InventoryRequest(
      id: 'req-003',
      workshopJobId: 'wj-003',
      platNomor: 'DK 9012 EF',
      kategoriServis: 'Ganti Filter',
      status: InventoryRequestStatus.diproses,
      items: const [
        InventoryRequestItem(
          id: 'ri-005',
          namaBarang: 'Filter Udara HD-700',
          jumlahDiminta: 1,
          jumlahTersedia: 3,
          satuan: 'Pcs',
          status: InventoryRequestItemStatus.tersedia,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  List<InventoryRequest> get _pendingRequests =>
      _mockRequests.where((r) => r.status == InventoryRequestStatus.pending).toList();

  int get _totalJenis => _mockItems.length;

  int get _stokMinimumCount =>
      _mockItems.where((i) => i.isStokRendah).length;

  @override
  Widget build(BuildContext context) {
    final pending = _pendingRequests;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: const [PortalSwitchButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildRingkasanCard(),
          const SizedBox(height: 20),
          _buildRequestSection(pending),
          const Divider(height: 32),
          _buildShortcutSection(),
        ],
      ),
    );
  }

  Widget _buildRingkasanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
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
          const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$_totalJenis jenis barang',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (_stokMinimumCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_stokMinimumCount di bawah minimum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _buildRequestSection(List<InventoryRequest> pending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.input_rounded, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Request Masuk dari Workshop',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'Request Pending',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${pending.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warningColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 32, color: AppTheme.successColor),
                SizedBox(height: 8),
                Text(
                  'Tidak ada request pending',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          )
        else
          for (final request in pending)
            QueueCard(
              leading: CircleAvatar(
                radius: 20,
                backgroundColor:
                    AppTheme.warningColor.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.build_rounded,
                  size: 20,
                  color: AppTheme.warningColor,
                ),
              ),
              title: '${request.platNomor} \u2022 ${request.kategoriServis}',
              subtitle: '${request.totalItems} item diminta',
              statusLabel: request.status.label,
              statusColor: AppTheme.warningColor,
              onTap: () => context.push('/inventory/request/${request.id}'),
            ),
      ],
    );
  }

  Widget _buildShortcutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Menu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ShortcutTile(
                icon: Icons.warehouse_outlined,
                title: 'Cek Stok',
                onTap: () => context.push('/inventory/stok'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ShortcutTile(
                icon: Icons.fact_check_outlined,
                title: 'Stok Opname',
                onTap: () => context.push('/inventory/opname'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ShortcutTile(
                icon: Icons.history_rounded,
                title: 'Riwayat',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Riwayat akan segera hadir'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
