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
import '../../shared/widgets/photo_viewer_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../../shared/widgets/submit_spinner.dart';
import 'armada_providers.dart';
import 'checklist_major_model.dart';
import 'checklist_major_store.dart';
import 'models/armada.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';

/// Checklist Major — Serah Terima Kendaraan (Section 21.10).
///
/// Workflow nyata 7 langkah: Pilih Kendaraan → Konteks Unit → Checklist
/// (progres "X / 10 dinilai") → Bukti Foto → Review (ringkasan kondisi +
/// perbandingan mode Kembali vs Berangkat) → Submit → Result.
/// Submit benar-benar memanggil backend (`POST /armada/checklist-major`
/// lewat outbox); hasilnya (tersinkron / antre / gagal) tampil apa adanya.
class ChecklistMajorScreen extends ConsumerStatefulWidget {
  const ChecklistMajorScreen({super.key});

  @override
  ConsumerState<ChecklistMajorScreen> createState() =>
      _ChecklistMajorScreenState();
}

enum _Step { pilih, konteks, checklist, evidence, review, result }

enum _SubmitOutcome { delivered, queued, failed }

class _ChecklistMajorScreenState extends ConsumerState<ChecklistMajorScreen> {
  final _catatanCtrl = TextEditingController();

  _Step _step = _Step.pilih;
  _SelectedUnit? _unit;
  MajorChecklistMode _mode = MajorChecklistMode.berangkat;
  List<MajorChecklistItem> _items = [];
  MajorChecklistSnapshot? _berangkatSnapshot;
  bool _isSubmitting = false;
  _SubmitOutcome? _outcome;
  String? _outcomeMessage;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigasi antar langkah
  // ---------------------------------------------------------------------------

  void _goBack() {
    switch (_step) {
      case _Step.pilih:
        Navigator.of(context).pop();
      case _Step.konteks:
        setState(() => _step = _Step.pilih);
      case _Step.checklist:
      case _Step.evidence:
      case _Step.review:
        setState(
          () => _step =
              _Step.values[_Step.values.indexOf(_step) - 1],
        );
      case _Step.result:
        setState(() {
          _step = _Step.review;
          _outcome = null;
          _outcomeMessage = null;
        });
    }
  }

  Future<void> _onUnitSelected(_SelectedUnit unit) async {
    setState(() {
      _unit = unit;
      _mode = MajorChecklistMode.berangkat;
      _berangkatSnapshot = null;
    });
    final snapshot = await ChecklistMajorStore.loadBerangkat(unit.id);
    if (!mounted) return;
    setState(() => _berangkatSnapshot = snapshot);
    setState(() => _step = _Step.konteks);
  }

  void _prepareChecklist() {
    final base = defaultMajorChecklistItems();
    final items =
        _mode == MajorChecklistMode.kembali && _berangkatSnapshot != null
            ? [
                for (final b in base)
                  b.copyWith(
                    status:
                        _berangkatSnapshot!.statusFor(b.label) ??
                        MajorChecklistStatus.belum,
                  ),
              ]
            : base;
    setState(() {
      _items = items;
      _step = _Step.checklist;
    });
  }

  // ---------------------------------------------------------------------------
  // Aksi foto
  // ---------------------------------------------------------------------------

  Future<void> _takePhoto(int index) async {
    if (_unit == null || index < 0 || index >= _items.length) return;
    HapticFeedback.lightImpact();
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null) return;
    if (!mounted) return;
    setState(() {
      _items[index] = _items[index].copyWith(photoPath: photo.path);
    });
  }

  void _deletePhoto(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(clearPhoto: true);
    });
  }

  // ---------------------------------------------------------------------------
  // Submit (backend nyata)
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    final unit = _unit;
    if (unit == null) return;
    if (!majorCanSubmit(_items)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi penilaian & bukti foto semua item dulu.'),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      final photoPaths = <String>[];
      final payload = <Map<String, dynamic>>[];
      for (final item in _items) {
        final entry = item.toPayload();
        if (item.photoPath != null) {
          entry['photo_index'] = photoPaths.length;
          photoPaths.add(item.photoPath!);
        }
        payload.add(entry);
      }

      final result = await ref
          .read(armadaRepositoryProvider)
          .submitChecklistMajor(
            armadaId: unit.id,
            items: payload,
            catatan: _catatanCtrl.text.trim(),
            photoPaths: photoPaths,
          );
      if (!mounted) return;

      if (result.delivered) {
        HapticFeedback.lightImpact();
        AnalyticsService.checklistSubmit(
          majorSummaryOf(_items).allBaik,
        );
        if (_mode == MajorChecklistMode.berangkat) {
          await ChecklistMajorStore.saveBerangkat(
            MajorChecklistSnapshot(
              armadaId: unit.id,
              tanggal: DateTime.now().toIso8601String(),
              items: [
                for (final i in _items) (label: i.label, status: i.status),
              ],
            ),
          );
        }
        if (!mounted) return;
        setState(() {
          _outcome = _SubmitOutcome.delivered;
          _outcomeMessage = null;
          _step = _Step.result;
        });
      } else if (result.permanentlyFailed) {
        setState(() {
          _outcome = _SubmitOutcome.failed;
          _outcomeMessage =
              result.errorMessage ?? 'Gagal menyimpan. Coba lagi.';
          _step = _Step.result;
        });
      } else {
        HapticFeedback.lightImpact();
        setState(() {
          _outcome = _SubmitOutcome.queued;
          _outcomeMessage = null;
          _step = _Step.result;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _outcome = _SubmitOutcome.failed;
        _outcomeMessage = e.message;
        _step = _Step.result;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _outcome = _SubmitOutcome.failed;
        _outcomeMessage = kCopyConnError;
        _step = _Step.result;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.pilih:
        return _VehicleSelectionStep(onSelected: _onUnitSelected);
      case _Step.konteks:
        return _buildKonteks(context);
      case _Step.checklist:
        return _buildChecklist(context);
      case _Step.evidence:
        return _buildEvidence(context);
      case _Step.review:
        return _buildReview(context);
      case _Step.result:
        return _buildResult(context);
    }
  }

  Widget _wizardScaffold({
    required Widget body,
    required String stepLabel,
    required int stepIndex,
    int totalSteps = 5,
    double? progress,
    Widget? bottomBar,
  }) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Kembali',
          onPressed: _goBack,
        ),
        title: Text('Checklist Serah Terima — ${_unit?.platNomor ?? ''}'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          _WizardStepHeader(
            stepLabel: stepLabel,
            stepIndex: stepIndex,
            totalSteps: totalSteps,
            progress: progress,
          ),
          Expanded(child: body),
          ?bottomBar,
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step: Konteks Unit
  // -------------------------------------------------------------------------

  Widget _buildKonteks(BuildContext context) {
    final unit = _unit;
    if (unit == null) {
      return _VehicleSelectionStep(onSelected: _onUnitSelected);
    }
    final colors = context.colors;
    final isAlatBerat = unit.tipeUnit == 'alat_berat_stasioner';
    final modeKembali = _mode == MajorChecklistMode.kembali;

    return _wizardScaffold(
      stepIndex: 1,
      stepLabel: 'Konteks Unit',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Unit yang diperiksa',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colors.primary.withValues(alpha: 0.1),
                        child: Icon(
                          isAlatBerat
                              ? Icons.precision_manufacturing_outlined
                              : Icons.local_shipping_outlined,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              unit.platNomor,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              [
                                if (unit.jenis != null &&
                                    unit.jenis!.isNotEmpty)
                                  unit.jenis!,
                                if (unit.kodeUnit != null &&
                                    unit.kodeUnit!.isNotEmpty)
                                  'Unit ${unit.kodeUnit}',
                              ].join(' • '),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (unit.titikNama != null)
                        _KonteksChip(
                          icon: Icons.location_on_outlined,
                          label: 'Titik: ${unit.titikNama}',
                        ),
                      if (unit.odoTerkini != null && !isAlatBerat)
                        _KonteksChip(
                          icon: Icons.speed_outlined,
                          label: 'ODO: ${fmtKm(unit.odoTerkini)}',
                        ),
                      if (unit.jamOperasionalTerkini != null && isAlatBerat)
                        _KonteksChip(
                          icon: Icons.schedule_outlined,
                          label: 'HM: ${fmtJam(unit.jamOperasionalTerkini)}',
                        ),
                      if (unit.status != null)
                        _KonteksChip(
                          icon: Icons.badge_outlined,
                          label: 'Status: ${unit.status}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mode Serah Terima',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<MajorChecklistMode>(
            segments: [
              for (final m in MajorChecklistMode.values)
                ButtonSegment(
                  value: m,
                  icon: Icon(
                    m == MajorChecklistMode.berangkat
                        ? Icons.directions_car_filled_outlined
                        : Icons.assignment_return_outlined,
                  ),
                  label: Text(m.label),
                ),
            ],
            selected: {_mode},
            onSelectionChanged: (sel) {
              setState(() => _mode = sel.first);
            },
          ),
          const SizedBox(height: 8),
          Text(
            _mode.subLabel,
            style: TextStyle(fontSize: 12, color: colors.textTertiary),
          ),
          if (modeKembali) ...[
            const SizedBox(height: 12),
            if (_berangkatSnapshot == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Belum ada catatan kondisi berangkat tersimpan di '
                        'perangkat ini. Kondisi kembali tidak bisa '
                        'dibandingkan otomatis.',
                        style: TextStyle(fontSize: 12, color: colors.textPrimary),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      color: colors.info,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kondisi berangkat (${fmtTanggal(_berangkatSnapshot!.tanggal)}) '
                        'akan dibandingkan di setiap item & di Review.',
                        style: TextStyle(fontSize: 12, color: colors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: BouncingButton(
            onPressed: _prepareChecklist,
            child: FilledButton(
              onPressed: _prepareChecklist,
              child: Text('Lanjut ke Checklist'),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step: Checklist (progres X / 10 dinilai)
  // -------------------------------------------------------------------------

  Widget _buildChecklist(BuildContext context) {
    final colors = context.colors;
    final assessed = majorAssessedCount(_items);
    final allAssessed = majorAllAssessed(_items);
    final modeKembali = _mode == MajorChecklistMode.kembali;

    return _wizardScaffold(
      stepIndex: 2,
      stepLabel: 'Isi Checklist',
      progress: _items.isEmpty ? 0 : assessed / _items.length,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$assessed / ${_items.length} dinilai',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _items.isEmpty || assessed == 0
                              ? 0
                              : assessed / _items.length,
                          minHeight: 6,
                          backgroundColor: colors.surfaceVariant,
                          color: allAssessed ? colors.success : colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _items = [
                        for (final i in _items)
                          i.copyWith(status: MajorChecklistStatus.baik),
                      ];
                    });
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Semua Baik'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _MajorItemTile(
                  item: item,
                  onStatusChanged: (status) {
                    setState(() {
                      _items[index] = _items[index].copyWith(status: status);
                    });
                    AnalyticsService.checklistItemToggle(
                      item.label,
                      status == MajorChecklistStatus.baik,
                    );
                  },
                  onTakePhoto: () => _takePhoto(index),
                  onDeletePhoto: () => _deletePhoto(index),
                  onPreview: () {
                    final p = _items[index].photoPath;
                    if (p == null) return;
                    PhotoViewerDialog.show(
                      context: context,
                      heroTag: 'major-$index',
                      filePath: p,
                      title: item.label,
                    );
                  },
                  berangkatHint: modeKembali
                      ? _berangkatSnapshot?.statusFor(item.label)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!allAssessed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nilai ${_items.length - assessed} item lagi untuk lanjut.',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: BouncingButton(
                onPressed: allAssessed
                    ? () => setState(() => _step = _Step.evidence)
                    : null,
                child: FilledButton(
                  onPressed: allAssessed
                      ? () => setState(() => _step = _Step.evidence)
                      : null,
                  child: const Text('Lanjut ke Bukti Foto'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step: Bukti Foto (item rusak)
  // -------------------------------------------------------------------------

  Widget _buildEvidence(BuildContext context) {
    final colors = context.colors;
    final needs = _items.where((i) => i.needsEvidence).toList();
    final complete = majorEvidenceComplete(_items);

    return _wizardScaffold(
      stepIndex: 3,
      stepLabel: 'Bukti Foto',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (needs.isEmpty)
            AppEmptyState(
              icon: Icons.verified_outlined,
              title: 'Semua Baik',
              subtitle: 'Tidak ada item rusak — bukti foto tidak diperlukan.',
            )
          else ...[
            Text(
              '${needs.length} item perlu bukti foto',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Foto wajib untuk setiap item yang dinilai rusak.',
              style: TextStyle(fontSize: 12, color: colors.textTertiary),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _items.length; i++)
              if (_items[i].needsEvidence)
                _EvidenceCard(
                  item: _items[i],
                  onTakePhoto: () => _takePhoto(i),
                  onDeletePhoto: () => _deletePhoto(i),
                  onPreview: () {
                    final p = _items[i].photoPath;
                    if (p == null) return;
                    PhotoViewerDialog.show(
                      context: context,
                      heroTag: 'major-evidence-$i',
                      filePath: p,
                      title: _items[i].label,
                    );
                  },
                ),
          ],
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!complete)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Lengkapi foto semua item rusak untuk lanjut.',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: BouncingButton(
                onPressed: complete
                    ? () => setState(() => _step = _Step.review)
                    : null,
                child: FilledButton(
                  onPressed: complete
                      ? () => setState(() => _step = _Step.review)
                      : null,
                  child: const Text('Lanjut ke Review'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step: Review + Submit
  // -------------------------------------------------------------------------

  Widget _buildReview(BuildContext context) {
    final colors = context.colors;
    final summary = majorSummaryOf(_items);
    final comparisons = _mode == MajorChecklistMode.kembali
        ? compareReturnToBerangkat(_items, snapshot: _berangkatSnapshot)
        : null;
    final changed = comparisons?.where((c) => c.berubah).toList() ?? const [];

    return _wizardScaffold(
      stepIndex: 4,
      stepLabel: 'Review & Kirim',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Ringkasan kondisi
          Card(
            color: colors.surfaceVariant.withValues(alpha: 0.6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan Kondisi',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SummaryCount(
                        label: 'Baik',
                        count: summary.baik,
                        color: colors.success,
                      ),
                      _SummaryCount(
                        label: 'Rusak Ringan',
                        count: summary.rusakRingan,
                        color: colors.warning,
                      ),
                      _SummaryCount(
                        label: 'Rusak Berat',
                        count: summary.rusakBerat,
                        color: colors.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${summary.totalAssessed} dari ${_items.length} item dinilai',
                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Perbandingan mode kembali vs berangkat
          if (comparisons != null && _berangkatSnapshot != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.compare_arrows,
                          size: 18,
                          color: colors.info,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Perbandingan dengan Berangkat',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (changed.isEmpty)
                      Text(
                        'Tidak ada perubahan kondisi dari berangkat.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textTertiary,
                        ),
                      )
                    else
                      for (final c in changed)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.change_circle_outlined,
                            color: colors.error,
                            size: 20,
                          ),
                          title: Text(
                            c.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Berangkat: ${c.berangkat?.label} → Kini: ${c.kini.label}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.warning,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit item',
                            onPressed: () =>
                                setState(() => _step = _Step.checklist),
                          ),
                          onTap: () =>
                              setState(() => _step = _Step.checklist),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Daftar item
          Text(
            'Rincian Item',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _items.length; i++)
            _ReviewItemRow(
              item: _items[i],
              berangkatHint: comparisons?.isNotEmpty == true
                  ? comparisons![i].berangkat
                  : null,
              onEdit: () => setState(() => _step = _Step.checklist),
              onPreview: () {
                final p = _items[i].photoPath;
                if (p == null) return;
                PhotoViewerDialog.show(
                  context: context,
                  heroTag: 'major-review-$i',
                  filePath: p,
                  title: _items[i].label,
                );
              },
            ),
          const SizedBox(height: 12),

          // Catatan
          TextField(
            controller: _catatanCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan Tambahan',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: BouncingButton(
            onPressed: _isSubmitting ? null : _submit,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SubmitSpinner(size: 18),
                        SizedBox(width: 8),
                        Text('Mengirim...'),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _mode == MajorChecklistMode.kembali
                              ? Icons.assignment_return_outlined
                              : Icons.verified_outlined,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Kirim Serah Terima (${_mode.label})',
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Step: Result (hasil submit nyata)
  // -------------------------------------------------------------------------

  Widget _buildResult(BuildContext context) {
    final colors = context.colors;
    final summary = majorSummaryOf(_items);
    final outcome = _outcome ?? _SubmitOutcome.failed;

    final (icon, iconColor, title, subtitle) = switch (outcome) {
      _SubmitOutcome.delivered => (
          Icons.check_circle_rounded,
          colors.success,
          'Tersimpan & Tersinkron',
          'Checklist serah terima ${_mode.label.toLowerCase()} diterima server.',
        ),
      _SubmitOutcome.queued => (
          Icons.cloud_queue_rounded,
          colors.warning,
          'Tersimpan di Perangkat',
          kCopyQueued,
        ),
      _SubmitOutcome.failed => (
          Icons.cancel_rounded,
          colors.error,
          'Gagal Menyimpan',
          _outcomeMessage ?? 'Terjadi kesalahan. Coba lagi.',
        ),
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Tutup',
          onPressed: () => _goBack(),
        ),
        title: const Text('Checklist Serah Terima'),
        actions: const [PortalSwitchButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: iconColor),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textTertiary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  summary.line,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (outcome == _SubmitOutcome.failed) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BouncingButton(
                    onPressed: () => _goBack(),
                    child: FilledButton(
                      onPressed: () => _goBack(),
                      child: const Text('Coba Lagi'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Keluar'),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BouncingButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Selesai'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widget pendukung
// =============================================================================

/// Header kontekstual tiap langkah wizard (index, nama, progres).
class _WizardStepHeader extends StatelessWidget {
  const _WizardStepHeader({
    required this.stepLabel,
    required this.stepIndex,
    required this.totalSteps,
    this.progress,
  });

  final String stepLabel;
  final int stepIndex;
  final int totalSteps;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: colors.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Langkah $stepIndex dari $totalSteps — $stepLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: colors.surfaceVariant,
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip info kecil di langkah Konteks Unit.
class _KonteksChip extends StatelessWidget {
  const _KonteksChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textTertiary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu item checklist: index, status, label, hint berangkat, bukti foto.
class _MajorItemTile extends StatelessWidget {
  const _MajorItemTile({
    required this.item,
    required this.onStatusChanged,
    required this.onTakePhoto,
    required this.onDeletePhoto,
    required this.onPreview,
    this.berangkatHint,
  });

  final MajorChecklistItem item;
  final ValueChanged<MajorChecklistStatus> onStatusChanged;
  final VoidCallback onTakePhoto;
  final VoidCallback onDeletePhoto;
  final VoidCallback onPreview;

  /// Kondisi item saat berangkat (mode kembali) — null bila tak tersedia.
  final MajorChecklistStatus? berangkatHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = item.status;
    final color = _majorStatusColor(context, status);
    final displayNum = item.index.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayNum,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (status.isAssessed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            if (berangkatHint != null && berangkatHint!.isAssessed) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 13,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Berangkat: ${berangkatHint!.label}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                for (final s in [
                  MajorChecklistStatus.baik,
                  MajorChecklistStatus.rusakRingan,
                  MajorChecklistStatus.rusakBerat,
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: OutlinedButton(
                        onPressed: () => onStatusChanged(s),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: status == s
                              ? _majorStatusColor(
                                  context,
                                  s,
                                ).withValues(alpha: 0.1)
                              : null,
                          side: BorderSide(
                            color: status == s
                                ? _majorStatusColor(context, s)
                                : colors.border,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: status == s
                                ? _majorStatusColor(context, s)
                                : colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _MajorEvidenceBox(
              photoPath: item.photoPath,
              heroTag: 'major-${item.index}',
              needsEvidence: item.needsEvidence,
              onTakePhoto: onTakePhoto,
              onDeletePhoto: onDeletePhoto,
              onPreview: onPreview,
            ),
          ],
        ),
      ),
    );
  }
}

/// Kotak bukti foto: tombol ambil foto / pratinjau + ganti + hapus.
class _MajorEvidenceBox extends StatelessWidget {
  const _MajorEvidenceBox({
    required this.photoPath,
    required this.heroTag,
    required this.needsEvidence,
    required this.onTakePhoto,
    required this.onDeletePhoto,
    required this.onPreview,
  });

  final String? photoPath;
  final String heroTag;
  final bool needsEvidence;
  final VoidCallback onTakePhoto;
  final VoidCallback onDeletePhoto;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final path = photoPath;

    if (path == null || path.isEmpty) {
      return Row(
        children: [
          OutlinedButton.icon(
            onPressed: onTakePhoto,
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text(needsEvidence ? 'Ambil Foto (wajib)' : 'Ambil Foto'),
          ),
          if (needsEvidence) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bukti foto diperlukan untuk item rusak.',
                style: TextStyle(fontSize: 11, color: colors.warning),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        GestureDetector(
          onTap: onPreview,
          child: Semantics(
            button: true,
            label: 'Lihat foto',
            child: Hero(
              tag: heroTag,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  cacheWidth: 200,
                  errorBuilder: (context, error, stack) => ColoredBox(
                    color: colors.surfaceVariant,
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Icon(Icons.image, color: colors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: onTakePhoto,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Ganti'),
        ),
        IconButton(
          onPressed: onDeletePhoto,
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: 'Hapus foto',
          color: colors.error,
        ),
      ],
    );
  }
}

/// Kartu bukti foto pada langkah Evidence (item rusak).
class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({
    required this.item,
    required this.onTakePhoto,
    required this.onDeletePhoto,
    required this.onPreview,
  });

  final MajorChecklistItem item;
  final VoidCallback onTakePhoto;
  final VoidCallback onDeletePhoto;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final color = _majorStatusColor(context, item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.index.toString().padLeft(2, '0')} • ${item.label}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _MajorEvidenceBox(
              photoPath: item.photoPath,
              heroTag: 'major-evidence-${item.index}',
              needsEvidence: true,
              onTakePhoto: onTakePhoto,
              onDeletePhoto: onDeletePhoto,
              onPreview: onPreview,
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris ringkas item pada layar Review (bisa diedit kembali).
class _ReviewItemRow extends StatelessWidget {
  const _ReviewItemRow({
    required this.item,
    required this.onEdit,
    required this.onPreview,
    this.berangkatHint,
  });

  final MajorChecklistItem item;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final MajorChecklistStatus? berangkatHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _majorStatusColor(context, item.status);
    final berubah =
        berangkatHint != null && berangkatHint!.isAssessed && berangkatHint != item.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Text(
            item.index.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.status.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (berubah)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Berangkat: ${berangkatHint!.label}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (item.photoPath != null)
                GestureDetector(
                  onTap: onPreview,
                  child: Semantics(
                    button: true,
                    label: 'Lihat foto item',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(item.photoPath!),
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        cacheWidth: 96,
                        errorBuilder: (context, error, stack) => ColoredBox(
                          color: colors.surfaceVariant,
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: Icon(Icons.image, size: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit item',
          onPressed: onEdit,
        ),
        onTap: onEdit,
      ),
    );
  }
}

/// Angka ringkasan kondisi (Baik / Ringan / Berat).
class _SummaryCount extends StatelessWidget {
  const _SummaryCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

Color _majorStatusColor(BuildContext context, MajorChecklistStatus s) {
  final colors = context.colors;
  return switch (s) {
    MajorChecklistStatus.belum => colors.textMuted,
    MajorChecklistStatus.baik => colors.success,
    MajorChecklistStatus.rusakRingan => colors.warning,
    MajorChecklistStatus.rusakBerat => colors.error,
  };
}

// =============================================================================
// Step 1: Pilih kendaraan
// =============================================================================

/// Unit terpilih — merangkum data dari `ArmadaSaya` (kaya konteks) atau
/// fallback `MasterArmada` (dropdown master).
class _SelectedUnit {
  const _SelectedUnit({
    required this.id,
    required this.platNomor,
    this.kodeUnit,
    this.jenis,
    this.tipeUnit,
    this.status,
    this.titikNama,
    this.odoTerkini,
    this.jamOperasionalTerkini,
  });

  final String id;
  final String platNomor;
  final String? kodeUnit;
  final String? jenis;
  final String? tipeUnit;
  final String? status;
  final String? titikNama;
  final double? odoTerkini;
  final double? jamOperasionalTerkini;

  factory _SelectedUnit.fromArmadaSaya(ArmadaSaya a) => _SelectedUnit(
    id: a.id,
    platNomor: a.platNomor,
    kodeUnit: a.kodeUnit,
    jenis: a.jenis,
    tipeUnit: a.tipeUnit,
    status: a.status,
    titikNama: a.titikNama,
    odoTerkini: a.odoTerkini,
    jamOperasionalTerkini: a.jamOperasionalTerkini,
  );

  factory _SelectedUnit.fromMaster(MasterArmada m) => _SelectedUnit(
    id: m.id,
    platNomor: m.platNomor,
    kodeUnit: m.kodeUnit,
    jenis: m.jenis,
    status: m.status,
  );
}

class _VehicleSelectionStep extends ConsumerWidget {
  const _VehicleSelectionStep({required this.onSelected});

  final ValueChanged<_SelectedUnit> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final armadaSayaAsync = ref.watch(armadaSayaProvider);
    final masterAsync = ref.watch(masterArmadaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Serah Terima'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: colors.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(
                  Icons.directions_car,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Langkah 1 dari 5 — Pilih Kendaraan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: armadaSayaAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => AppEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Gagal memuat data armada',
                subtitle:
                    'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
                actionLabel: 'Coba lagi',
                onAction: () => ref.invalidate(armadaSayaProvider),
              ),
              data: (armadaList) {
                if (armadaList.isNotEmpty) {
                  return _builtinList(
                    context,
                    colors,
                    title: 'Kendaraan Anda',
                    children: [
                      for (final a in armadaList)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: Icon(
                              Icons.local_shipping,
                              color: colors.primary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            a.platNomor,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            [
                              if (a.jenis != null && a.jenis!.isNotEmpty)
                                a.jenis!,
                              if (a.titikNama != null) 'Titik ${a.titikNama}',
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textTertiary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              onSelected(_SelectedUnit.fromArmadaSaya(a)),
                        ),
                    ],
                  );
                }

                // Fallback: daftar master armada (dropdown servis).
                return masterAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Gagal memuat data armada',
                    subtitle:
                        'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
                    actionLabel: 'Coba lagi',
                    onAction: () => ref.invalidate(masterArmadaProvider),
                  ),
                  data: (masterList) {
                    if (masterList.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: 'Tidak ada armada',
                        subtitle: 'Belum ada unit armada terdaftar.',
                      );
                    }
                    return _builtinList(
                      context,
                      colors,
                      title: 'Seluruh Unit',
                      children: [
                        for (final m in masterList)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colors.primary.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                Icons.local_shipping,
                                color: colors.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              m.platNomor,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (m.kodeUnit != null &&
                                    m.kodeUnit!.isNotEmpty)
                                  'Unit ${m.kodeUnit}',
                                if (m.jenis != null && m.jenis!.isNotEmpty)
                                  m.jenis!,
                                if (m.status != null) m.status!,
                              ].join(' • '),
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textTertiary,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                onSelected(_SelectedUnit.fromMaster(m)),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _builtinList(
    BuildContext context,
    AppColors colors, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          color: colors.primary.withValues(alpha: 0.05),
          child: Row(
            children: [
              Icon(
                Icons.directions_car,
                color: colors.primary,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        ),
      ],
    );
  }
}