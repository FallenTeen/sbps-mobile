import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'armada_providers.dart';
import 'checklist_draft_store.dart';
import 'models/armada.dart';

const _dailyItems = <String>[
  'Ban',
  'Rem',
  'Lampu',
  'Oli mesin',
  'Air radiator',
  'Body',
  'Kabin',
  'Dokumen & STNK',
];

/// Checklist harian armada: daftar unit hari ini, isi per item dengan autosave.
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, this.isAkhir = false});

  final bool isAkhir;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  Future<void> _openForm(ArmadaChecklist item) async {
    final armadaList = ref.read(armadaSayaProvider).value;
    final armada = armadaList?.where((a) => a.id == item.armadaId).firstOrNull;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChecklistFillScreen(
          item: item,
          isAkhir: widget.isAkhir,
          odoTerkini: armada?.odoTerkini,
          jamOperasionalTerkini: armada?.jamOperasionalTerkini,
          isAlatBerat: armada?.isAlatBerat ?? false,
        ),
      ),
    );
    ref.invalidate(checklistHariIniProvider);
    ref.invalidate(checklistAkhirDoneProvider(item.armadaId));
  }

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(checklistHariIniProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          widget.isAkhir ? 'Checklist akhir' : 'Checklist harian',
        ),
        actions:  [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(checklistHariIniProvider),
        child: switch (checklist) {
          AsyncData(value: final items) => items.isEmpty
              ? AppEmptyState(
                  icon: Icons.checklist_rtl,
                  title: 'Belum ada armada untuk dicatat',
                  subtitle:
                      'Armada yang ditugaskan ke titik Anda akan muncul di sini.',
                  actionLabel: 'Muat Ulang',
                  onAction: () => ref.invalidate(checklistHariIniProvider),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ChecklistCard(
                    item: items[i],
                    onTap: () => _openForm(items[i]),
                  ),
                ),
          AsyncError() => AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Gagal memuat data checklist',
              subtitle:
                  'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
              actionLabel: 'Coba Lagi',
              onAction: () => ref.invalidate(checklistHariIniProvider),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.item, required this.onTap});

  final ArmadaChecklist item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = item.sudahIsi;
    return Card(
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          filled ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: filled ? context.colors.success : context.colors.textMuted,
          size: 28,
        ),
        title: Text(
          item.platNomor,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          filled
              ? (item.kondisiBaik == true
                  ? 'Kondisi baik${_masalahSuffix(item.itemBermasalah)}'
                  : 'Ada masalah${_masalahSuffix(item.itemBermasalah)}')
              : 'Belum dicatat hari ini',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  String _masalahSuffix(String? masalah) =>
      (masalah == null || masalah.isEmpty) ? '' : ' — $masalah';
}

class _ItemState {
  _ItemState({required this.label, this.baik = true, this.photoPath});

  final String label;
  bool baik;
  String? photoPath;
}

class _ChecklistFillScreen extends ConsumerStatefulWidget {
  const _ChecklistFillScreen({
    required this.item,
    required this.isAkhir,
    this.odoTerkini,
    this.jamOperasionalTerkini,
    required this.isAlatBerat,
  });

  final ArmadaChecklist item;
  final bool isAkhir;
  final double? odoTerkini;
  final double? jamOperasionalTerkini;
  final bool isAlatBerat;

  @override
  ConsumerState<_ChecklistFillScreen> createState() =>
      _ChecklistFillScreenState();
}

class _ChecklistFillScreenState extends ConsumerState<_ChecklistFillScreen> {
  late List<_ItemState> _items;
  final _solarCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  final _jamCtrl = TextEditingController();
  bool _busy = false;
  bool _draftLoaded = false;
  String? _draftHint;

  @override
  void initState() {
    super.initState();
    _items = [for (final label in _dailyItems) _ItemState(label: label)];
    if (widget.item.solarLiter != null) {
      _solarCtrl.text = widget.item.solarLiter.toString();
    }
    if (widget.item.odoKm != null) {
      _odoCtrl.text = widget.item.odoKm.toString();
    } else if (widget.odoTerkini != null) {
      _odoCtrl.text = widget.odoTerkini!.toStringAsFixed(0);
    }
    if (widget.item.jamOperasional != null) {
      _jamCtrl.text = widget.item.jamOperasional.toString();
    } else if (widget.jamOperasionalTerkini != null) {
      _jamCtrl.text = widget.jamOperasionalTerkini.toString();
    }
    _solarCtrl.addListener(_autosave);
    _odoCtrl.addListener(_autosave);
    _jamCtrl.addListener(_autosave);
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await ChecklistDraftStore.load(
      widget.item.armadaId,
      isAkhir: widget.isAkhir,
    );
    if (!mounted || draft == null) {
      setState(() => _draftLoaded = true);
      return;
    }
    final savedItems = draft['items'];
    if (savedItems is List) {
      for (final raw in savedItems) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final label = map['label']?.toString();
        final match = _items.where((i) => i.label == label).firstOrNull;
        if (match == null) continue;
        match.baik = map['baik'] != false;
        match.photoPath = map['photo_path']?.toString();
      }
    }
    _solarCtrl.text = draft['solar']?.toString() ?? _solarCtrl.text;
    _odoCtrl.text = draft['odo']?.toString() ?? _odoCtrl.text;
    _jamCtrl.text = draft['jam']?.toString() ?? _jamCtrl.text;
    setState(() {
      _draftLoaded = true;
      _draftHint = 'Draft tersimpan di HP';
    });
  }

  Future<void> _autosave() async {
    if (!_draftLoaded) return;
    await ChecklistDraftStore.save(
      widget.item.armadaId,
      isAkhir: widget.isAkhir,
      data: {
        'items': [
          for (final i in _items)
            {
              'label': i.label,
              'baik': i.baik,
              'photo_path': i.photoPath,
            },
        ],
        'solar': _solarCtrl.text,
        'odo': _odoCtrl.text,
        'jam': _jamCtrl.text,
      },
    );
    if (mounted) {
      setState(() => _draftHint = 'Tersimpan otomatis');
    }
  }

  @override
  void dispose() {
    _solarCtrl.dispose();
    _odoCtrl.dispose();
    _jamCtrl.dispose();
    super.dispose();
  }

  Future<void> _setItemBaik(_ItemState item, bool baik) async {
    HapticFeedback.selectionClick();
    setState(() => item.baik = baik);
    AnalyticsService.checklistItemToggle(item.label, baik);
    if (!baik && (item.photoPath == null || item.photoPath!.isEmpty)) {
      final photo = await takeWatermarkedPhoto(ref);
      if (photo != null && mounted) {
        setState(() => item.photoPath = photo.path);
      }
    }
    await _autosave();
  }

  Future<void> _retakePhoto(_ItemState item) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo != null && mounted) {
      setState(() => item.photoPath = photo.path);
      await _autosave();
    }
  }

  List<_ItemState> get _bermasalah =>
      _items.where((i) => !i.baik).toList();

  Future<void> _confirmAndSubmit() async {
    final issues = _bermasalah;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ringkasan sebelum kirim',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                widget.item.platNomor,
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                issues.isEmpty
                    ? 'Semua item: baik (${_items.length} dari ${_items.length})'
                    : '${_items.length - issues.length} baik · ${issues.length} tidak baik',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final i in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${i.label}${i.photoPath != null ? ' · ada foto' : ''}'),
                  ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Kirim checklist'),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Periksa lagi'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed == true) await _submit();
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final issues = _bermasalah;
      final delivered =
          await ref.read(armadaRepositoryProvider).submitChecklist(
                armadaId: widget.item.armadaId,
                kondisiBaik: issues.isEmpty,
                itemBermasalah: issues.map((i) => i.label).join(', '),
                solarLiter: double.tryParse(_solarCtrl.text),
                odoKm: double.tryParse(_odoCtrl.text),
                jamOperasional: double.tryParse(_jamCtrl.text),
                itemDetails: [
                  for (final i in _items)
                    {
                      'label': i.label,
                      'baik': i.baik,
                      if (i.photoPath != null) 'has_foto': true,
                    },
                ],
              );
      if (widget.isAkhir) {
        await ChecklistDraftStore.markAkhirSubmitted(widget.item.armadaId);
      }
      await ChecklistDraftStore.clear(
        widget.item.armadaId,
        isAkhir: widget.isAkhir,
      );
      if (!mounted) return;
      AnalyticsService.checklistSubmit(issues.isEmpty);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? 'Checklist tersimpan.'
                : 'Menunggu Terkirim — tersimpan di HP, dikirim otomatis saat online.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menyimpan checklist.\nPeriksa koneksi lalu coba lagi.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(widget.item.platNomor),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_draftHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _draftHint!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
              ),
            ),
          Text(
            widget.isAkhir
                ? 'Periksa kondisi unit di akhir hari. Ketuk Baik / Tidak baik pada tiap item.'
                : 'Periksa kondisi unit. Ketuk Baik / Tidak baik pada tiap item.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          SizedBox(height: 12),
          for (final item in _items) ...[
            _ItemTile(
              item: item,
              onBaik: () => _setItemBaik(item, true),
              onTidakBaik: () => _setItemBaik(item, false),
              onFoto: () => _retakePhoto(item),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text(
            'Data operasional',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _solarCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Stok Solar (liter)',
              border: OutlineInputBorder(),
              helperText: 'Jumlah solar yang diisi hari ini',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isAlatBerat)
            TextField(
              controller: _jamCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jam Kerja Unit (HM)',
                border: OutlineInputBorder(),
                helperText: 'Total jam mesin menyala hari ini',
              ),
            )
          else
            TextField(
              controller: _odoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'KM Sekarang (Odometer)',
                border: OutlineInputBorder(),
                helperText:
                    'Angka pada odometer (penghitung km) kendaraan',
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: BouncingButton(
              onPressed: _busy ? null : _confirmAndSubmit,
              child: FilledButton(
                onPressed: _busy ? null : _confirmAndSubmit,
                child: Text(_busy ? 'Menyimpan...' : 'Lihat ringkasan & kirim'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.onBaik,
    required this.onTidakBaik,
    required this.onFoto,
  });

  final _ItemState item;
  final VoidCallback onBaik;
  final VoidCallback onTidakBaik;
  final VoidCallback onFoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ToggleChip(
                  label: 'Baik',
                  selected: item.baik,
                  selectedColor: context.colors.success,
                  onTap: onBaik,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ToggleChip(
                  label: 'Tidak baik',
                  selected: !item.baik,
                  selectedColor: context.colors.error,
                  onTap: onTidakBaik,
                ),
              ),
            ],
          ),
          if (!item.baik) ...[
            const SizedBox(height: 10),
            if (item.photoPath != null && File(item.photoPath!).existsSync())
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(item.photoPath!),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onFoto,
                    child: const Text('Ambil ulang foto'),
                  ),
                ],
              )
            else
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onFoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Ambil foto kerusakan'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: selected
            ? selectedColor.withValues(alpha: 0.12)
            : context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? selectedColor : context.colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? selectedColor : context.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
