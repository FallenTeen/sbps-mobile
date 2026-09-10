import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'inventory_models.dart';

class InventoryOpnameScreen extends ConsumerStatefulWidget {
  const InventoryOpnameScreen({super.key});

  @override
  ConsumerState<InventoryOpnameScreen> createState() =>
      _InventoryOpnameScreenState();
}

class _InventoryOpnameScreenState extends ConsumerState<InventoryOpnameScreen> {
  final List<OpnameItem> _mockItems = [
    const OpnameItem(
      id: 'op-001',
      namaBarang: 'Oli Mesin 15W-40',
      kategori: 'Pelumas',
      jumlahSistem: 24,
      satuan: 'Liter',
    ),
    const OpnameItem(
      id: 'op-002',
      namaBarang: 'Filter Udara HD-700',
      kategori: 'Filter',
      jumlahSistem: 3,
      satuan: 'Pcs',
    ),
    const OpnameItem(
      id: 'op-003',
      namaBarang: 'Kampas Rem Depan',
      kategori: 'Rem',
      jumlahSistem: 8,
      satuan: 'Set',
    ),
    const OpnameItem(
      id: 'op-004',
      namaBarang: 'Bearing Roda Depan',
      kategori: 'Suku Cadang',
      jumlahSistem: 2,
      satuan: 'Pcs',
    ),
    const OpnameItem(
      id: 'op-005',
      namaBarang: 'Belt Alternator',
      kategori: 'Belt',
      jumlahSistem: 6,
      satuan: 'Pcs',
    ),
  ];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, int?> _fisikValues = {};

  @override
  void initState() {
    super.initState();
    for (final item in _mockItems) {
      _controllers[item.id] = TextEditingController();
      _fisikValues[item.id] = null;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onFisikChanged(String itemId, String value) {
    final parsed = int.tryParse(value);
    setState(() {
      _fisikValues[itemId] = parsed;
    });
  }

  bool get _hasChanges => _fisikValues.values.any((v) => v != null);

  int get _selisihCount =>
      _mockItems.where((i) => _fisikValues[i.id] != null && _fisikValues[i.id] != i.jumlahSistem).length;

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Opname disimpan \u2022 $_selisihCount item selisih',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Stok Opname'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.infoColor.withValues(alpha: 0.08),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppTheme.infoColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bandingkan jumlah fisik dengan catatan sistem',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.infoColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _mockItems.isEmpty
                ? const AppEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Tidak ada data stok',
                    subtitle: 'Belum ada barang untuk opname',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mockItems.length,
                    itemBuilder: (context, index) {
                      final item = _mockItems[index];
                      return _OpnameItemCard(
                        item: item,
                        controller: _controllers[item.id]!,
                        fisikValue: _fisikValues[item.id],
                        onChanged: (v) => _onFisikChanged(item.id, v),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _hasChanges
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(
                    'Simpan Opname${_selisihCount > 0 ? ' ($_selisihCount selisih)' : ''}',
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _OpnameItemCard extends StatelessWidget {
  const _OpnameItemCard({
    required this.item,
    required this.controller,
    required this.fisikValue,
    required this.onChanged,
  });

  final OpnameItem item;
  final TextEditingController controller;
  final int? fisikValue;
  final ValueChanged<String> onChanged;

  bool get _hasSelisih =>
      fisikValue != null && fisikValue != item.jumlahSistem;

  int? get _selisih =>
      fisikValue != null ? fisikValue! - item.jumlahSistem : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasSelisih
              ? AppTheme.errorColor.withValues(alpha: 0.3)
              : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.namaBarang,
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
                  const Text(
                    'Sistem',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    '${item.jumlahSistem}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    hintText: 'Jumlah fisik',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                    suffixText: item.satuan,
                  ),
                ),
              ),
              if (_hasSelisih) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selisih! > 0 ? '+' : ''}$_selisih',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
