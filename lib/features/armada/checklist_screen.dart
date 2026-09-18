import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/rich_list_tile.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'armada_providers.dart';
import 'checklist_draft_store.dart';
import 'checklist_model.dart';
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

/// Checklist harian armada: work queue unit hari ini (summary + filter) dan
/// form per item dengan autosave.
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, this.isAkhir = false});

  final bool isAkhir;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  ChecklistFilterK _filter = ChecklistFilterK.semua;

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
        title: Text(widget.isAkhir ? 'Checklist akhir' : 'Checklist harian'),
        actions: [PortalSwitchButton()],
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
              : _ChecklistQueue(
                  items: items,
                  isAkhir: widget.isAkhir,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onTap: _openForm,
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

/// Work queue hari ini: header summary, filter tab, lalu daftar unit.
class _ChecklistQueue extends StatelessWidget {
  const _ChecklistQueue({
    required this.items,
    required this.isAkhir,
    required this.filter,
    required this.onFilterChanged,
    required this.onTap,
  });

  final List<ArmadaChecklist> items;
  final bool isAkhir;
  final ChecklistFilterK filter;
  final ValueChanged<ChecklistFilterK> onFilterChanged;
  final void Function(ArmadaChecklist) onTap;

  @override
  Widget build(BuildContext context) {
    final summary = checklistSummary(items);
    final filtered = applyChecklistFilter(items, filter);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SummaryHeader(summary: summary, isAkhir: isAkhir),
        const SizedBox(height: 12),
        _FilterChips(
          current: filter,
          summary: summary,
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: AppEmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Tidak ada unit dengan status ini',
              subtitle:
                  'Ubah filter untuk melihat unit lain hari ini.',
            ),
          )
        else
          for (final c in filtered) ...[
            _ChecklistCard(item: c, isAkhir: isAkhir, onTap: () => onTap(c)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary, required this.isAkhir});

  final ChecklistSummary summary;
  final bool isAkhir;

  @override
  Widget build(BuildContext context) {
    final allDone = summary.menunggu == 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone
              ? context.colors.success.withValues(alpha: 0.35)
              : context.colors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 20,
                color: allDone
                    ? context.colors.success
                    : context.colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isAkhir
                    ? 'Checklist Akhir Kendaraan Hari Ini'
                    : 'Checklist Kendaraan Hari Ini',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${summary.checked}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: allDone
                      ? context.colors.success
                      : context.colors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  'dari ${summary.total} sudah diperiksa',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary.menunggu == 0
                ? 'Semua unit sudah diperiksa hari ini.'
                : '${summary.menunggu} masih menunggu.'
                      '${summary.bermasalah > 0 ? ' ${summary.bermasalah} bermasalah.' : ''}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: summary.bermasalah > 0
                  ? context.colors.warning
                  : context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: summary.progressRatio,
              minHeight: 8,
              backgroundColor: context.colors.surfaceVariant,
              color: allDone
                  ? context.colors.success
                  : context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.current,
    required this.summary,
    required this.onChanged,
  });

  final ChecklistFilterK current;
  final ChecklistSummary summary;
  final ValueChanged<ChecklistFilterK> onChanged;

  @override
  Widget build(BuildContext context) {
    final zipped = [
      (ChecklistFilterK.semua, summary.total),
      (ChecklistFilterK.belumDicek, summary.menunggu),
      (ChecklistFilterK.bermasalah, summary.bermasalah),
      (ChecklistFilterK.selesai, summary.checked - summary.bermasalah),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in zipped) ...[
            ChoiceChip(
              label: Text(
                entry.$1 == ChecklistFilterK.semua
                    ? entry.$1.label
                    : '${entry.$1.label} (${entry.$2})',
              ),
              selected: current == entry.$1,
              onSelected: (_) => onChanged(entry.$1),
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: current == entry.$1
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: current == entry.$1
                    ? context.colors.primary
                    : context.colors.textSecondary,
              ),
              selectedColor: context.colors.primary.withValues(alpha: 0.12),
              backgroundColor: context.colors.surfaceVariant,
              side: BorderSide(
                color: current == entry.$1
                    ? context.colors.primary
                    : context.colors.border,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.item,
    required this.isAkhir,
    required this.onTap,
  });

  final ArmadaChecklist item;
  final bool isAkhir;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = unitChecklistStatus(item);
    final filled = item.sudahIsi;

    final (title, subtitle, color) = switch (status) {
      ChecklistUnitStatus.selesai => (
          'Sudah diperiksa — kondisi baik',
          '${_tanggalInfo(item)}${_masalahSuffix(item.itemBermasalah)}',
          context.colors.success,
        ),
      ChecklistUnitStatus.bermasalah => (
          filled
              ? 'Sudah diperiksa — ada masalah${_masalahSuffix(item.itemBermasalah)}'
              : 'Ada masalah',
          'Periksa kondisi dan lampirkan catatan kondisi unit',
          context.colors.error,
        ),
      ChecklistUnitStatus.menunggu => (
          'Menunggu diperiksa',
          _belumDicekSubtitle(item),
          context.colors.textMuted,
        ),
    };

    return RichListTile(
      title: item.platNomor,
      subtitle: subtitle,
      meta: isAkhir
          ? 'Akhir'
          : status == ChecklistUnitStatus.bermasalah
          ? 'Bermasalah'
          : 'Harian',
      metaColor: status == ChecklistUnitStatus.bermasalah
          ? context.colors.error
          : null,
      leading: _ChecklistStatusLeading(color: color, status: status),
      onTap: onTap,
    );
  }

  String _belumDicekSubtitle(ArmadaChecklist item) {
    final checkDate = _parseDate(item.tanggal);
    final daysAgo = checkDate == null ? null : _daysSince(checkDate);
    return switch (daysAgo) {
      null => 'Belum dicatat hari ini · Belum pernah dicek',
      0 => 'Belum dicatat hari ini',
      1 => 'Belum dicatat hari ini · Terakhir: kemarin',
      _ => 'Belum dicatat hari ini · Terakhir: $daysAgo hari lalu',
    };
  }

  String _tanggalInfo(ArmadaChecklist item) {
    final odo = item.odoKm;
    final jam = item.jamOperasional;
    if (odo != null && odo > 0) return 'ODO ${fmtKm(odo)}';
    if (jam != null && jam > 0) return 'HM ${fmtJam(jam)}';
    return 'Hari ini';
  }

  DateTime? _parseDate(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return null;
    return DateTime.tryParse(tanggal);
  }

  int _daysSince(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return today.difference(target).inDays;
  }

  String _masalahSuffix(String? masalah) =>
      (masalah == null || masalah.isEmpty) ? '' : ' — $masalah';
}

/// Leading status checklist: hijau berisi centang (selesai), merah tanda bahaya
/// (bermasalah), abu outline (belum dicek).
class _ChecklistStatusLeading extends StatelessWidget {
  const _ChecklistStatusLeading({required this.color, required this.status});

  final Color color;
  final ChecklistUnitStatus status;

  @override
  Widget build(BuildContext context) {
    final tinted = color.withValues(alpha: 0.12);
    final isHighlighted = status != ChecklistUnitStatus.menunggu;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isHighlighted ? tinted : null,
        border: isHighlighted ? null : Border.all(color: color, width: 2),
      ),
      child: Icon(
        switch (status) {
          ChecklistUnitStatus.selesai => Icons.check_rounded,
          ChecklistUnitStatus.bermasalah => Icons.error_outline_rounded,
          ChecklistUnitStatus.menunggu => Icons.radio_button_unchecked_rounded,
        },
        color: color,
        size: 26,
      ),
    );
  }
}

// ── Form isi checklist ────────────────────────────────────────────────────────

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
  late List<ChecklistItemDraft> _items;
  late List<TextEditingController> _catatanCtrls;
  final _solarCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  final _jamCtrl = TextEditingController();
  double? _odoPrev;
  double? _jamPrev;
  bool _busy = false;
  bool _draftLoaded = false;
  String? _draftHint;

  @override
  void initState() {
    super.initState();
    _items = [for (final label in _dailyItems) ChecklistItemDraft(label: label)];
    _catatanCtrls = [
      for (final _ in _dailyItems) TextEditingController(),
    ];

    _odoPrev = _positive(widget.item.odoKm) ? widget.item.odoKm : widget.odoTerkini;
    _jamPrev = _positive(widget.item.jamOperasional)
        ? widget.item.jamOperasional
        : widget.jamOperasionalTerkini;

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
    for (final c in _catatanCtrls) {
      c.addListener(_onCatatanChanged);
    }
    _restoreDraft();
  }

  bool _positive(double? v) => v != null && v.isFinite && v > 0;

  @override
  void dispose() {
    _solarCtrl.dispose();
    _odoCtrl.dispose();
    _jamCtrl.dispose();
    for (final c in _catatanCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _onCatatanChanged() {
    if (!_draftLoaded) return;
    for (var i = 0; i < _items.length; i++) {
      final text = _catatanCtrls[i].text;
      if (_items[i].catatan != text) {
        _items[i] = _items[i].copyWith(catatan: text);
      }
    }
    _autosave();
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
      for (var i = 0; i < _items.length; i++) {
        final match = savedItems
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .where((m) => m['label'] == _items[i].label)
            .firstOrNull;
        if (match == null) continue;
        final levelRaw = match['level']?.toString();
        final level = ChecklistItemLevel.values
            .where((l) => l.wireValue == levelRaw)
            .firstOrNull ??
            ChecklistItemLevel.baik;
        _items[i] = _items[i].copyWith(
          level: level,
          photoPath: match['photo_path']?.toString(),
          catatan: match['catatan']?.toString() ?? '',
        );
        _catatanCtrls[i].text = match['catatan']?.toString() ?? '';
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
              'level': i.level.wireValue,
              'catatan': i.catatan,
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

  Future<void> _setLevel(int index, ChecklistItemLevel level) async {
    HapticFeedback.selectionClick();
    final item = _items[index];
    setState(() {
      _items[index] = item.copyWith(level: level);
    });
    AnalyticsService.checklistItemToggle(item.label, !level.isBermasalah);

    // Rusak/Tidak Aman wajib ada foto bukti: langsung buka kamera.
    if (level == ChecklistItemLevel.rusak &&
        (item.photoPath == null || item.photoPath!.isEmpty)) {
      final photo = await takeWatermarkedPhoto(ref);
      if (photo != null && mounted) {
        final updated = _items[index];
        setState(() {
          _items[index] = updated.copyWith(photoPath: photo.path);
        });
      }
    }
    await _autosave();
  }

  Future<void> _takePhoto(int index) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo != null && mounted) {
      final updated = _items[index];
      setState(() {
        _items[index] = updated.copyWith(photoPath: photo.path);
      });
      await _autosave();
    }
  }

  List<ChecklistItemDraft> get _bermasalah =>
      _items.where((i) => i.level.isBermasalah).toList();

  Future<void> _confirmAndSubmit() async {
    final issues = _bermasalah;

    final rusakNoFoto = _items
        .where(
          (i) =>
              i.level == ChecklistItemLevel.rusak &&
              (i.photoPath == null || i.photoPath!.isEmpty),
        )
        .map((i) => i.label)
        .toList();
    if (rusakNoFoto.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ambil foto kerusakan terlebih dahulu: ${rusakNoFoto.join(', ')}',
          ),
        ),
      );
      return;
    }

    final rusakNoDesc = _items
        .where(
          (i) =>
              i.level == ChecklistItemLevel.rusak &&
              i.catatan.trim().isEmpty,
        )
        .map((i) => i.label)
        .toList();
    if (rusakNoDesc.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Jelaskan masalahnya terlebih dahulu: ${rusakNoDesc.join(', ')}',
          ),
        ),
      );
      return;
    }

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
                _summaryLine(issues),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (issues.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final i in issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${i.label} — ${i.level.label}'
                      '${i.catatan.trim().isNotEmpty ? ' · ${i.catatan.trim()}' : ''}'
                      '${i.photoPath != null ? ' · ada foto' : ''}',
                    ),
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

  String _summaryLine(List<ChecklistItemDraft> issues) {
    final baik = _items.length - issues.length;
    final perhatian = issues
        .where((i) => i.level == ChecklistItemLevel.perluPerhatian)
        .length;
    final rusak = issues.length - perhatian;
    if (issues.isEmpty) {
      return 'Semua item: baik (${_items.length} dari ${_items.length})';
    }
    final parts = <String>['$baik baik'];
    if (perhatian > 0) parts.add('$perhatian perlu perhatian');
    if (rusak > 0) parts.add('$rusak rusak / tidak aman');
    return parts.join(' · ');
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final issues = _bermasalah;
      final delivered = await ref
          .read(armadaRepositoryProvider)
          .submitChecklist(
            armadaId: widget.item.armadaId,
            kondisiBaik: issues.isEmpty,
            isAkhir: widget.isAkhir,
            itemBermasalah: issues.map((i) => i.label).join(', '),
            solarLiter: double.tryParse(_solarCtrl.text),
            odoKm: double.tryParse(_odoCtrl.text),
            jamOperasional: double.tryParse(_jamCtrl.text),
            itemDetails: [for (final i in _items) i.toPayload()],
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
                ? (widget.isAkhir
                      ? 'Checklist akhir berhasil disimpan.'
                      : 'Checklist harian berhasil disimpan.')
                : kCopyQueued,
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              friendlyErrorMessage(
                e,
                fallback: 'Gagal menyimpan checklist. Periksa koneksi lalu coba lagi.',
              ),
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
      appBar: AppBar(title: Text(widget.item.platNomor)),
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
                ? 'Periksa kondisi unit di akhir hari. Pilih Baik, Perlu Perhatian, atau Rusak / Tidak Aman untuk tiap item.'
                : 'Periksa kondisi unit. Pilih Baik, Perlu Perhatian, atau Rusak / Tidak Aman untuk tiap item.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          SizedBox(height: 12),
          for (var i = 0; i < _items.length; i++) ...[
            _ItemTile(
              item: _items[i],
              catatanCtrl: _catatanCtrls[i],
              onLevelChanged: (level) => _setLevel(i, level),
              onFoto: () => _takePhoto(i),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          _DataOperasionalSection(
            isAlatBerat: widget.isAlatBerat,
            solarCtrl: _solarCtrl,
            odoCtrl: _odoCtrl,
            jamCtrl: _jamCtrl,
            odoReading: OdoReading(
              previous: _odoPrev,
              current: double.tryParse(_odoCtrl.text),
            ),
            jamReading: OdoReading(
              previous: _jamPrev,
              current: double.tryParse(_jamCtrl.text),
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

/// Bagian data operasional: solar + ODO/HM dengan previous/current/delta dan
/// warning ketika nilainya turun dari bacaan sebelumnya.
class _DataOperasionalSection extends StatelessWidget {
  const _DataOperasionalSection({
    required this.isAlatBerat,
    required this.solarCtrl,
    required this.odoCtrl,
    required this.jamCtrl,
    required this.odoReading,
    required this.jamReading,
  });

  final bool isAlatBerat;
  final TextEditingController solarCtrl;
  final TextEditingController odoCtrl;
  final TextEditingController jamCtrl;
  final OdoReading odoReading;
  final OdoReading jamReading;

  @override
  Widget build(BuildContext context) {
    final reading = isAlatBerat ? jamReading : odoReading;
    final activeCtrl = isAlatBerat ? jamCtrl : odoCtrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data operasional',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: solarCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Stok Solar (liter)',
              border: OutlineInputBorder(),
              helperText: 'Jumlah solar yang diisi hari ini',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: activeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: isAlatBerat
                  ? 'Jam Kerja Unit (HM)'
                  : 'KM Sekarang (Odometer)',
              border: const OutlineInputBorder(),
              helperText: isAlatBerat
                  ? 'Total jam mesin menyala — Hour Meter'
                  : 'Angka pada odometer (penghitung km) kendaraan',
            ),
          ),
          const SizedBox(height: 10),
          _OdoCompare(
            isAlatBerat: isAlatBerat,
            reading: reading,
          ),
        ],
      ),
    );
  }
}

class _OdoCompare extends StatelessWidget {
  const _OdoCompare({required this.isAlatBerat, required this.reading});

  final bool isAlatBerat;
  final OdoReading reading;

  @override
  Widget build(BuildContext context) {
    if (!reading.hasBoth) {
      if (reading.previous == null) return const SizedBox.shrink();
    }

    final sebelumnya = isAlatBerat
        ? fmtJam(reading.previous)
        : fmtKm(reading.previous);
    final satuan = isAlatBerat ? 'jam' : 'km';

    if (!reading.hasBoth) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Sebelumnya: $sebelumnya',
          style: TextStyle(
            fontSize: 12,
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    final deltaLbl = reading.pemakaianLabel(isAlatBerat);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: reading.decreased
            ? context.colors.error.withValues(alpha: 0.06)
            : context.colors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: reading.decreased
              ? context.colors.error.withValues(alpha: 0.35)
              : context.colors.success.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sebelumnya: $sebelumnya · Sekarang: ${isAlatBerat ? fmtJam(reading.current) : fmtKm(reading.current)}',
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          if (reading.decreased)
            Text(
              'Perhatian: nilai $satuan ini lebih kecil dari bacaan sebelumnya '
              '(selisih $deltaLbl). Pastikan angka odometer/jam yang dimasukkan benar.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.error,
              ),
            )
          else
            Text(
              'Pemakaian: $deltaLbl',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.colors.success,
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
    required this.catatanCtrl,
    required this.onLevelChanged,
    required this.onFoto,
  });

  final ChecklistItemDraft item;
  final TextEditingController catatanCtrl;
  final ValueChanged<ChecklistItemLevel> onLevelChanged;
  final VoidCallback onFoto;

@override
  Widget build(BuildContext context) {
    final bermasalah = item.level.isBermasalah;

return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
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
                  label: ChecklistItemLevel.baik.label,
                  selected: item.level == ChecklistItemLevel.baik,
                  selectedColor: context.colors.success,
                  onTap: () => onLevelChanged(ChecklistItemLevel.baik),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ToggleChip(
                  label: ChecklistItemLevel.perluPerhatian.label,
                  selected: item.level == ChecklistItemLevel.perluPerhatian,
                  selectedColor: context.colors.warning,
                  onTap: () =>
                      onLevelChanged(ChecklistItemLevel.perluPerhatian),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _ToggleChip(
                  label: ChecklistItemLevel.rusak.label,
                  selected: item.level == ChecklistItemLevel.rusak,
                  selectedColor: context.colors.error,
                  onTap: () => onLevelChanged(ChecklistItemLevel.rusak),
                ),
              ),
            ],
          ),
          if (bermasalah) ...[
            const SizedBox(height: 10),
            TextField(
              controller: catatanCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: item.level == ChecklistItemLevel.rusak
                    ? 'Jelaskan masalah (wajib)'
                    : 'Jelaskan kondisi (opsional)',
                border: const OutlineInputBorder(),
                hintText: item.level == ChecklistItemLevel.rusak
                    ? 'Contoh: rem tidak pakem saat mengerem'
                    : 'Contoh: suara mesin kasar',
              ),
            ),
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
                      cacheWidth: 200,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.level == ChecklistItemLevel.rusak
                          ? 'Foto bukti kerusakan sudah tersedia.'
                          : 'Foto bukti tersedia.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onFoto,
                    child: const Text('Ambil ulang'),
                  ),
                ],
              )
            else
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onFoto,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    item.level == ChecklistItemLevel.rusak
                        ? 'Ambil foto kerusakan (wajib)'
                        : 'Ambil foto (opsional)',
                  ),
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
    return ConstrainedBox(
      // minHeight 48 (bukan fixed): baris tetap ≥48dp, namun bisa tumbuh
      // bila label wrap di text scale 130%.
      constraints: const BoxConstraints(minHeight: 48),
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
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? selectedColor : context.colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? selectedColor
                    : context.colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}