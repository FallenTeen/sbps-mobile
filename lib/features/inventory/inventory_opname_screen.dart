import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../features/presensi/models/titik.dart';
import '../presensi/presensi_providers.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';

class InventoryOpnameScreen extends ConsumerStatefulWidget {
  const InventoryOpnameScreen({super.key});

  @override
  ConsumerState<InventoryOpnameScreen> createState() =>
      _InventoryOpnameScreenState();
}

class _InventoryOpnameScreenState extends ConsumerState<InventoryOpnameScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, int?> _fisikValues = {};
  String? _selectedTitikId;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<OpnameItem> items) {
    for (final item in items) {
      _controllers.putIfAbsent(item.id, TextEditingController.new);
    }
  }

  void _onFisikChanged(String itemId, String value) {
    final parsed = int.tryParse(value);
    setState(() => _fisikValues[itemId] = parsed);
  }

  void _clearFisik(List<OpnameItem> items) {
    for (final item in items) {
      _controllers[item.id]?.clear();
      _fisikValues[item.id] = null;
    }
    setState(() {});
  }

  bool get _hasChanges => _fisikValues.values.any((v) => v != null);

  int _selisihCount(Iterable<OpnameItem> items) => items
      .where(
        (i) =>
            _fisikValues[i.id] != null && _fisikValues[i.id] != i.jumlahSistem,
      )
      .length;

  Future<void> _submit({
    required String titikId,
    required List<OpnameItem> items,
  }) async {
    final tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final submitItems = [
      for (final item in items)
        if (_fisikValues[item.id] != null)
          OpnameSubmitItem(
            bahanBakuId: item.id,
            saldoFisik: _fisikValues[item.id]!,
          ),
    ];
    if (submitItems.isEmpty) return;

    final result = await ref
        .read(inventoryOpnameProvider.notifier)
        .submit(titikId: titikId, tanggal: tanggal, items: submitItems);

    if (!mounted) return;

    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Opname gagal: ${result.error}')));
      return;
    }

    HapticFeedback.mediumImpact();
    if (result.delivered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opname berhasil disinkronkan \u2022 ${_selisihCount(items)} item selisih',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Opname tersimpan di perangkat \u2022 ${_selisihCount(items)} item selisih. Menunggu sinkronisasi.',
          ),
        ),
      );
    }
    _clearFisik(items);
  }

  @override
  Widget build(BuildContext context) {
    final titikAsync = ref.watch(titikAktifProvider);
    final materialsAsync = ref.watch(inventoryOpnameMaterialsProvider);
    final opnameState = ref.watch(inventoryOpnameProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Stok Opname'),
        actions: [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.colors.info.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.colors.info,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bandingkan jumlah fisik dengan catatan sistem',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Titik kerja',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: titikAsync.when(
                    loading: () => const SkeletonLoader(
                      child: SkeletonBlock(height: 36, borderRadius: 10),
                    ),
                    error: (error, _) => Text(
                      'Gagal memuat titik.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.error,
                      ),
                    ),
                    data: (titiks) => _buildTitikDropdown(titiks),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: materialsAsync.when(
              loading: () => const SkeletonLoader(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SkeletonBlock(height: 96, borderRadius: 14),
                      SizedBox(height: 10),
                      SkeletonBlock(height: 96, borderRadius: 14),
                      SizedBox(height: 10),
                      SkeletonBlock(height: 96, borderRadius: 14),
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
                      'Gagal memuat item opname.',
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(inventoryOpnameMaterialsProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                _initControllers(items);
                if (items.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'Tidak ada data stok',
                    subtitle: 'Belum ada barang untuk opname',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _OpnameItemCard(
                      item: item,
                      controller: _controllers[item.id]!,
                      fisikValue: _fisikValues[item.id],
                      onChanged: (v) => _onFisikChanged(item.id, v),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _hasChanges && _selectedTitikId != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: opnameState.busy
                      ? null
                      : () {
                          final titikId = _selectedTitikId!;
                          final items = materialsAsync.value ?? [];
                          _submit(titikId: titikId, items: items);
                        },
                  child: opnameState.busy
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Simpan Opname${_selisihCount(materialsAsync.value ?? []) > 0 ? ' (${_selisihCount(materialsAsync.value ?? const [])} selisih)' : ''}',
                        ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTitikDropdown(List<Titik> titiks) {
    if (titiks.isEmpty) {
      return Text(
        'Tidak ada titik aktif.',
        style: TextStyle(fontSize: 12, color: context.colors.textTertiary),
      );
    }
    _selectedTitikId ??= titiks.first.id;

    return DropdownButtonFormField<String>(
      initialValue: _selectedTitikId,
      isExpanded: true,
      items: [
        for (final t in titiks)
          DropdownMenuItem(
            value: t.id,
            child: Text(
              t.displayProyek != null && t.displayProyek!.isNotEmpty
                  ? '${t.nama} (${t.displayProyek})'
                  : t.nama,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _selectedTitikId = v);
      },
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
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

  bool get _hasSelisih => fisikValue != null && fisikValue != item.jumlahSistem;

  int? get _selisih =>
      fisikValue != null ? fisikValue! - item.jumlahSistem : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasSelisih
              ? context.colors.error.withValues(alpha: 0.3)
              : context.colors.border,
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
                    'Sistem',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.colors.textMuted,
                    ),
                  ),
                  Text(
                    '${item.jumlahSistem}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
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
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selisih! > 0 ? '+' : ''}$_selisih',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.error,
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
