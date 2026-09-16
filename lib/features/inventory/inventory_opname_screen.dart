import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../features/presensi/models/titik.dart';
import '../presensi/presensi_providers.dart';
import 'inventory_models.dart';
import 'inventory_providers.dart';
import 'inventory_rules.dart' as rules;

class InventoryOpnameScreen extends ConsumerStatefulWidget {
  const InventoryOpnameScreen({super.key});

  @override
  ConsumerState<InventoryOpnameScreen> createState() =>
      _InventoryOpnameScreenState();
}

class _InventoryOpnameScreenState extends ConsumerState<InventoryOpnameScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, TextEditingController> _catatanControllers = {};
  final Map<String, int?> _fisikValues = {};
  final Map<String, String?> _catatanValues = {};
  String? _selectedTitikId;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _catatanControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(List<OpnameItem> items) {
    for (final item in items) {
      _controllers.putIfAbsent(item.id, TextEditingController.new);
      _catatanControllers.putIfAbsent(item.id, TextEditingController.new);
    }
  }

  void _onFisikChanged(String itemId, String value) {
    final parsed = int.tryParse(value);
    setState(() => _fisikValues[itemId] = parsed);
  }

  void _onCatatanChanged(String itemId, String value) {
    setState(() => _catatanValues[itemId] = value);
  }

  void _clearFisik(List<OpnameItem> items) {
    for (final item in items) {
      _controllers[item.id]?.clear();
      _catatanControllers[item.id]?.clear();
      _fisikValues[item.id] = null;
      _catatanValues[item.id] = null;
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

  /// Review sheet — ringkas hasil hitung, lalu konfirmasi sebelum submit.
  Future<bool> _reviewAndConfirm({
    required List<OpnameItem> items,
    required List<Titik> titiks,
    required String titikId,
  }) async {
    final review = rules.opnameReview(items, _fisikValues, _catatanValues);
    final tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReviewSheet(
        review: review,
        tanggal: tanggal,
        titikLabel: _titikLabelFor(titiks, titikId),
      ),
    );
    if (proceed != true || !mounted) return false;

    final nSelisih = review.selisihItems.length;
    final confirmed = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.destructive,
      title: 'Simpan Opname?',
      message: nSelisih == 0
          ? 'Jumlah fisik sesuai sistem untuk semua item yang dihitung. '
                'Opname tetap akan dicatat pada tanggal semula.'
          : '$nSelisih item memiliki selisih. Stok sistem akan diperbarui '
                'sesuai hitung fisik dan tidak dapat dibatalkan.',
      confirmLabel: 'Ya, Simpan Opname',
      icon: Icons.fact_check_outlined,
    );
    return confirmed?.confirmed == true;
  }

  Future<void> _submit({
    required String titikId,
    required List<OpnameItem> items,
  }) async {
    final tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final submitItems = rules.opnameSubmitItems(
      items,
      _fisikValues,
      _catatanValues,
    );
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

  Future<void> _onBottomAction({
    required List<OpnameItem> items,
    required List<Titik> titiks,
    required String titikId,
  }) async {
    final go = await _reviewAndConfirm(titiks: titiks, items: items, titikId: titikId);
    if (!go || !mounted) return;
    await _submit(titikId: titikId, items: items);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: context.colors.info.withValues(alpha: 0.08),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.colors.info,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Bandingkan jumlah fisik dengan catatan sistem',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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
                      catatanController: _catatanControllers[item.id]!,
                      fisikValue: _fisikValues[item.id],
                      onChanged: (v) => _onFisikChanged(item.id, v),
                      onCatatanChanged: (v) => _onCatatanChanged(item.id, v),
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
                          final titiks = titikAsync.value ?? [];
                          _onBottomAction(
                            titiks: titiks,
                            items: items,
                            titikId: titikId,
                          );
                        },
                  child: opnameState.busy
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Review & Simpan Opname${_selisihCount(materialsAsync.value ?? []) > 0 ? ' (${_selisihCount(materialsAsync.value ?? const [])} selisih)' : ''}',
                        ),
                ),
              ),
            )
          : null,
    );
  }

  String _titikLabelFor(List<Titik> titiks, String titikId) {
    final titik = titiks.where((t) => t.id == titikId).firstOrNull;
    if (titik == null) return titikId;
    final proyek = titik.displayProyek;
    return proyek != null && proyek.isNotEmpty
        ? '${titik.nama} ($proyek)'
        : titik.nama;
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

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({
    required this.review,
    required this.tanggal,
    required this.titikLabel,
  });

  final rules.OpnameReview review;
  final String tanggal;
  final String titikLabel;

  @override
  Widget build(BuildContext context) {
    final nSelisih = review.selisihItems.length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fact_check_outlined,
                    color: context.colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review Opname',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$titikLabel \u2022 $tanggal',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (nSelisih > 0 ? context.colors.error : context.colors.success)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${review.totalDihitung} dihitung',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: nSelisih > 0
                          ? context.colors.error
                          : context.colors.success,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (nSelisih == 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: context.colors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Jumlah fisik sesuai sistem untuk semua item yang dihitung.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: review.selisihItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final s = review.selisihItems[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: context.colors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s.namaBarang,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${s.selisih > 0 ? '+' : ''}${s.selisih}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.error,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sistem ${s.sistem} \u2192 Fisik ${s.fisik}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textTertiary,
                            ),
                          ),
                          if (s.catatan != null && s.catatan!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Catatan: ${s.catatan}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.textSecondary,
                      side: BorderSide(color: context.colors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text('Lanjutkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpnameItemCard extends StatelessWidget {
  const _OpnameItemCard({
    required this.item,
    required this.controller,
    required this.catatanController,
    required this.fisikValue,
    required this.onChanged,
    required this.onCatatanChanged,
  });

  final OpnameItem item;
  final TextEditingController controller;
  final TextEditingController catatanController;
  final int? fisikValue;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCatatanChanged;

  bool get _hasSelisih => fisikValue != null && fisikValue != item.jumlahSistem;

  int? get _selisih =>
      fisikValue != null ? fisikValue! - item.jumlahSistem : null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
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
              if (fisikValue != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Catatan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (fisikValue != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: catatanController,
              onChanged: onCatatanChanged,
              decoration: const InputDecoration(
                hintText: 'Catatan (opsional)',
                prefixIcon: Icon(
                  Icons.note_alt_outlined,
                  size: 18,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}