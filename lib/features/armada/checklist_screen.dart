import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../core/watermark_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/draft_restore_banner.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'armada_providers.dart';
import 'checklist_draft_store.dart';
import 'checklist_model.dart';
import 'models/armada.dart';

/// Daftar bagian default checklist (dipakai bila server belum mengirim).
const _bagianDefault = <String>[
  'Ban',
  'Rem',
  'Lampu',
  'Oli mesin',
  'Air radiator',
  'Body',
  'Kabin',
];

/// Opsi stok solar fallback (6 level) bila server belum mengirim.
const _stokSolarFallback = <OpsiStokSolar>[
  OpsiStokSolar(value: 'hampir_habis', label: 'Hampir Habis'),
  OpsiStokSolar(value: 'seperempat', label: '1/4 Tangki'),
  OpsiStokSolar(value: 'setengah', label: '1/2 Tangki'),
  OpsiStokSolar(value: 'tiga_perempat', label: '3/4 Tangki'),
  OpsiStokSolar(value: 'hampir_penuh', label: 'Hampir Penuh'),
  OpsiStokSolar(value: 'penuh', label: 'Penuh'),
];

/// Checklist awal / akhir armada — pilih unit, isi data operasional, dan
/// periksa tiap bagian dalam accordion.
///
/// [isAkhir] = true untuk checklist akhir (final setelah dikirim).
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key, this.isAkhir = false});

  final bool isAkhir;

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  String? _armadaId;

  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(widget.isAkhir ? 'Checklist Akhir' : 'Checklist Awal'),
        actions: [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat data armada',
          subtitle:
              'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(armadaSayaProvider),
        ),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const AppEmptyState(
              icon: Icons.no_crash_outlined,
              title: 'Belum ada unit yang ditugaskan',
              subtitle: 'Hubungi admin untuk penugasan unit.',
            );
          }
          if (armadaList.length == 1 && _armadaId != armadaList.first.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _armadaId != armadaList.first.id) {
                setState(() => _armadaId = armadaList.first.id);
              }
            });
          }
          final armada = armadaList.length == 1
              ? armadaList.first
              : armadaList.where((a) => a.id == _armadaId).firstOrNull;

          final items = checklistAsync.value ?? const <ArmadaChecklist>[];
          final item = armada == null
              ? null
              : items.where((c) => c.armadaId == armada.id).firstOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (armadaList.length > 1)
                DropdownButtonFormField<String>(
                  initialValue: _armadaId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Kendaraan',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                    helperText: 'Pilih unit yang Anda operasikan hari ini',
                  ),
                  items: armadaList
                      .map(
                        (a) => DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            '${a.platNomor} — ${a.jenis ?? a.kodeUnit ?? ''}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _armadaId = v),
                ),
              if (armada != null) ...[
                const SizedBox(height: 12),
                _ArmadaHeader(armada: armada),
                const SizedBox(height: 16),
                if (checklistAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _ChecklistForm(
                    key: ValueKey('${armada.id}-${widget.isAkhir}'),
                    armada: armada,
                    item: item,
                    isAkhir: widget.isAkhir,
                  ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'Pilih unit untuk memulai checklist.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArmadaHeader extends StatelessWidget {
  const _ArmadaHeader({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final baris = [
      armada.platNomor,
      if (armada.kodeUnit != null) armada.kodeUnit!,
      armada.jenis ?? (armada.isAlatBerat ? 'Alat Berat' : 'Kendaraan'),
      if (armada.titikNama != null) armada.titikNama!,
    ].join(' • ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping, size: 18, color: context.colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              baris,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _BagianState {
  _BagianState({required this.bagian});

  final String bagian;
  ChecklistItemLevel? level;
  String catatan = '';
  String? fotoPath;
}

/// Nama field foto checklist awal/akhir.
enum _FotoSlot { stokSolar, odo }

class _ChecklistForm extends ConsumerStatefulWidget {
  const _ChecklistForm({
    super.key,
    required this.armada,
    required this.item,
    required this.isAkhir,
  });

  final ArmadaSaya armada;
  final ArmadaChecklist? item;
  final bool isAkhir;

  @override
  ConsumerState<_ChecklistForm> createState() => _ChecklistFormState();
}

class _ChecklistFormState extends ConsumerState<_ChecklistForm>
    with WidgetsBindingObserver {
  late List<_BagianState> _bagian;
  late List<TextEditingController> _catatanCtrl;
  final _odoCtrl = TextEditingController();

  String? _stokSolar;
  CapturedPhoto? _fotoStok;
  CapturedPhoto? _fotoOdo;
  String? _fotoStokUrl;
  String? _fotoOdoUrl;
  int? _expanded;
  bool _busy = false;

  Timer? _autosaveTimer;
  bool _autosaveStopped = false;
  bool _draftFound = false;
  bool _submittedLocal = false;
  DateTime? _draftSavedAt;
  Map<String, dynamic>? _pendingDraft;

  bool get _readOnly {
    if (widget.isAkhir) return widget.item?.akhir != null;
    final awal = widget.item?.awal;
    if (awal == null) return false;
    return !awal.bisaDiedit;
  }

  bool get _isEdit => widget.item?.awal != null && !widget.isAkhir;

  String? get _lockReason {
    if (!widget.isAkhir) return widget.item?.awal?.alasanTerkunci;
    return null;
  }

  @override
  void initState() {
    super.initState();
    final bagianList =
        widget.item?.bagianDefault.isNotEmpty == true
            ? widget.item!.bagianDefault
            : _bagianDefault;
    _bagian = [for (final b in bagianList) _BagianState(bagian: b)];
    _catatanCtrl = [for (final _ in _bagian) TextEditingController()];

    _prefillFromItem();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDraft());
  }

  void _prefillFromItem() {
    for (var i = 0; i < _bagian.length; i++) {
      _bagian[i]
        ..level = null
        ..catatan = ''
        ..fotoPath = null;
      _catatanCtrl[i].clear();
    }
    _stokSolar = null;
    _fotoStok = null;
    _fotoOdo = null;
    _fotoStokUrl = null;
    _fotoOdoUrl = null;
    _odoCtrl.clear();

    if (widget.isAkhir) {
      final a = widget.item?.akhir;
      if (a != null) {
        _stokSolar = a.stokSolar;
        _fotoStokUrl = a.fotoStokSolarUrl;
        _fotoOdoUrl = a.fotoOdoAkhirUrl;
        _odoCtrl.text = _fmtNum(
          widget.armada.isAlatBerat ? a.hmAkhir : a.odoAkhir,
        );
        _applyItems(a.items);
      }
    } else {
      final a = widget.item?.awal;
      if (a != null) {
        _stokSolar = a.stokSolar;
        _fotoStokUrl = a.fotoStokSolarUrl;
        _fotoOdoUrl = a.fotoOdoPagiUrl;
        _odoCtrl.text = _fmtNum(
          widget.armada.isAlatBerat ? a.hmOdo : a.odoPagi,
        );
        _applyItems(a.items);
      }
      if (_odoCtrl.text.isEmpty) {
        final t = widget.armada.isAlatBerat
            ? widget.armada.jamOperasionalTerkini
            : widget.armada.odoTerkini;
        _odoCtrl.text = _fmtNum(t);
      }
    }
    _expanded = _firstUnfilled();
  }

  void _applyItems(List<Map<String, dynamic>> items) {
    for (final raw in items) {
      final bagian = raw['bagian']?.toString();
      if (bagian == null) continue;
      final idx = _bagian.indexWhere((b) => b.bagian == bagian);
      if (idx < 0) continue;
      final kondisi = raw['kondisi']?.toString();
      _bagian[idx]
        ..level = ChecklistItemLevel.values
            .where((l) => l.wireValue == kondisi)
            .firstOrNull
        ..catatan = raw['catatan']?.toString() ?? ''
        ..fotoPath = raw['foto']?.toString();
      _catatanCtrl[idx].text = _bagian[idx].catatan;
    }
  }

  int? _firstUnfilled() {
    for (var i = 0; i < _bagian.length; i++) {
      if (_bagian[i].level == null) return i;
    }
    return null;
  }

  /// Indeks bagian pertama dengan [gap] dokumentasi, atau null.
  int? _firstGap(ChecklistDocGap gap) {
    for (var i = 0; i < _bagian.length; i++) {
      final b = _bagian[i];
      if (checklistBagianGap(b.level, b.catatan, b.fotoPath) == gap) return i;
    }
    return null;
  }

  /// Nama bagian yang punya [gap] (untuk pesan snackbar).
  List<String> _namesWithGap(ChecklistDocGap gap) => [
    for (final b in _bagian)
      if (checklistBagianGap(b.level, b.catatan, b.fotoPath) == gap) b.bagian,
  ];

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushAutosave();
    _odoCtrl.dispose();
    for (final c in _catatanCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _flushAutosave();
  }

  void _scheduleAutosave() {
    if (_autosaveStopped || _submittedLocal || _readOnly) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  void _flushAutosave() {
    if (_autosaveTimer == null) return;
    _autosaveTimer!.cancel();
    _saveDraft();
  }

  void _saveDraft() {
    _autosaveTimer = null;
    if (_autosaveStopped || _submittedLocal || _readOnly) return;
    ChecklistDraftStore.save(
      widget.armada.id,
      isAkhir: widget.isAkhir,
      data: _draftSnapshot(),
    ).ignore();
  }

  Map<String, dynamic> _draftSnapshot() => {
    'savedAt': DateTime.now().toIso8601String(),
    if (_stokSolar != null) 'stokSolar': _stokSolar,
    'odo': _odoCtrl.text,
    if (_fotoStok != null) 'fotoStok': _fotoStok!.path,
    if (_fotoOdo != null) 'fotoOdo': _fotoOdo!.path,
    'bagian': [
      for (var i = 0; i < _bagian.length; i++)
        {
          'bagian': _bagian[i].bagian,
          if (_bagian[i].level != null) 'kondisi': _bagian[i].level!.wireValue,
          'catatan': _catatanCtrl[i].text,
          if (_bagian[i].fotoPath != null) 'foto': _bagian[i].fotoPath,
        },
    ],
  };

  Future<void> _checkDraft() async {
    if (!mounted || _readOnly) return;
    Map<String, dynamic>? data;
    try {
      data = await ChecklistDraftStore.load(
        widget.armada.id,
        isAkhir: widget.isAkhir,
      );
    } catch (_) {
      return;
    }
    if (!mounted || data == null) return;
    if (widget.isAkhir && data['submitted'] == true) {
      _submittedLocal = true;
      return;
    }
    final savedAt = DateTime.tryParse(data['savedAt']?.toString() ?? '');
    setState(() {
      _pendingDraft = data;
      _draftSavedAt = savedAt ?? DateTime.now();
      _draftFound = true;
    });
  }

  void _continueDraft() {
    final data = _pendingDraft;
    setState(() {
      _draftFound = false;
      _pendingDraft = null;
    });
    if (data != null) _restoreDraft(data);
  }

  Future<void> _discardDraft() async {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    try {
      await ChecklistDraftStore.clear(
        widget.armada.id,
        isAkhir: widget.isAkhir,
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _draftFound = false;
      _pendingDraft = null;
      _prefillFromItem();
    });
  }

  void _restoreDraft(Map<String, dynamic> data) {
    setState(() {
      final opsi =
          widget.item?.opsiStokSolar.isNotEmpty == true
              ? widget.item!.opsiStokSolar
              : _stokSolarFallback;
      final stok = data['stokSolar'];
      if (stok is String && opsi.any((o) => o.value == stok)) _stokSolar = stok;
      final odo = data['odo'];
      if (odo is String) _odoCtrl.text = odo;
      final fotoStok = data['fotoStok'];
      if (fotoStok is String &&
          fotoStok.isNotEmpty &&
          File(fotoStok).existsSync()) {
        _fotoStok = CapturedPhoto(
          path: fotoStok,
          gpsStatus: GpsStatus.unavailable,
          latitude: null,
          longitude: null,
        );
      }
      final fotoOdo = data['fotoOdo'];
      if (fotoOdo is String &&
          fotoOdo.isNotEmpty &&
          File(fotoOdo).existsSync()) {
        _fotoOdo = CapturedPhoto(
          path: fotoOdo,
          gpsStatus: GpsStatus.unavailable,
          latitude: null,
          longitude: null,
        );
      }
      final bagianRaw = data['bagian'];
      if (bagianRaw is List) {
        for (final raw in bagianRaw) {
          if (raw is! Map) continue;
          final m = Map<String, dynamic>.from(raw);
          final nama = m['bagian']?.toString();
          if (nama == null) continue;
          final idx = _bagian.indexWhere((b) => b.bagian == nama);
          if (idx < 0) continue;
          final kondisi = m['kondisi']?.toString();
          final fotoPath = m['foto']?.toString();
          _bagian[idx]
            ..level =
                ChecklistItemLevel.values
                    .where((l) => l.wireValue == kondisi)
                    .firstOrNull
            ..catatan = m['catatan']?.toString() ?? ''
            ..fotoPath =
                (fotoPath != null && File(fotoPath).existsSync())
                ? fotoPath
                : null;
          _catatanCtrl[idx].text = _bagian[idx].catatan;
        }
      }
      _expanded = _firstUnfilled();
    });
  }

  void _setLevel(int index, ChecklistItemLevel level) {
    if (_readOnly) return;
    HapticFeedback.selectionClick();
    setState(() {
      final b = _bagian[index];
      b.level = level;
      AnalyticsService.checklistItemToggle(b.bagian, !level.isBermasalah);
      // Item bermasalah: accordion tetap terbuka di item ini supaya form
      // dokumentasi (catatan + foto) langsung terlihat. Item baik: lanjut
      // ke bagian berikutnya yang belum diperiksa.
      _expanded = nextExpandedIndexAfterLevel(
        index: index,
        level: level,
        levels: [for (final x in _bagian) x.level],
      );
    });
    _scheduleAutosave();
  }

  Future<void> _pickFoto(_FotoSlot slot) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null || !mounted) return;
    setState(() {
      if (slot == _FotoSlot.stokSolar) {
        _fotoStok = photo;
      } else {
        _fotoOdo = photo;
      }
    });
    _scheduleAutosave();
  }

  Future<void> _pickItemFoto(int index) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null || !mounted) return;
    setState(() => _bagian[index].fotoPath = photo.path);
    _scheduleAutosave();
  }

  Future<void> _submit() async {
    if (widget.isAkhir) {
      final confirm = await ConfirmationDialog.show(
        context,
        severity: ConfirmSeverity.destructive,
        title: 'Kirim Checklist Akhir?',
        message:
            'Checklist akhir bersifat final dan tidak dapat diedit setelah '
            'dikirim. Koreksi ODO/HM harus diajukan melalui Ketua Armada. '
            'Lanjutkan pengiriman?',
        confirmLabel: 'Ya, Kirim',
      );
      if (!mounted || confirm?.confirmed != true) return;
    }
    final armada = widget.armada;
    final isAlatBerat = armada.isAlatBerat;
    final odo = double.tryParse(_odoCtrl.text.trim());

    if (_stokSolar == null || _stokSolar!.isEmpty) {
      _snack('Pilih perkiraan stok solar terlebih dahulu.');
      return;
    }
    if (_fotoStok == null && _fotoStokUrl == null) {
      _snack('Foto indikator stok solar wajib diambil dari kamera.');
      return;
    }
    if (odo == null) {
      _snack(isAlatBerat ? 'HM wajib diisi.' : 'ODO wajib diisi.');
      return;
    }
    if (_fotoOdo == null && _fotoOdoUrl == null) {
      _snack(
        isAlatBerat
            ? 'Foto HM wajib diambil dari kamera.'
            : 'Foto ODO wajib diambil dari kamera.',
      );
      return;
    }
    final belumIdx = _firstGap(ChecklistDocGap.belumDiperiksa);
    if (belumIdx != null) {
      setState(() => _expanded = belumIdx);
      _snack(
        'Masih ada bagian yang belum diperiksa: '
        '${_namesWithGap(ChecklistDocGap.belumDiperiksa).join(', ')}',
      );
      return;
    }
    final catatanIdx = _firstGap(ChecklistDocGap.catatanKosong);
    if (catatanIdx != null) {
      setState(() => _expanded = catatanIdx);
      _snack(
        'Jelaskan kondisi: '
        '${_namesWithGap(ChecklistDocGap.catatanKosong).join(', ')}',
      );
      return;
    }
    final rusakFotoIdx = _firstGap(ChecklistDocGap.rusakTanpaFoto);
    if (rusakFotoIdx != null) {
      setState(() => _expanded = rusakFotoIdx);
      _snack(
        'Ambil foto kerusakan: '
        '${_namesWithGap(ChecklistDocGap.rusakTanpaFoto).join(', ')}',
      );
      return;
    }
    final perluFotoIdx = _firstGap(ChecklistDocGap.perluPerhatianTanpaFoto);
    if (perluFotoIdx != null) {
      setState(() => _expanded = perluFotoIdx);
      _snack(
        'Ambil foto kondisi: '
        '${_namesWithGap(ChecklistDocGap.perluPerhatianTanpaFoto).join(', ')}',
      );
      return;
    }

    final items = [
      for (final b in _bagian)
        checklistItemPayload(
          bagian: b.bagian,
          level: b.level!,
          catatan: b.catatan,
          fotoPath: b.fotoPath,
        ),
    ];

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(armadaRepositoryProvider);
      final delivered = widget.isAkhir
          ? await repo.submitChecklistAkhir(
              armadaId: armada.id,
              items: items,
              stokSolar: _stokSolar!,
              odoAkhir: isAlatBerat ? null : odo,
              hmAkhir: isAlatBerat ? odo : null,
              fotoStokSolarPath: _fotoStok?.path,
              fotoOdoAkhirPath: _fotoOdo?.path,
            )
          : await repo.submitChecklistAwal(
              armadaId: armada.id,
              items: items,
              stokSolar: _stokSolar!,
              odoPagi: isAlatBerat ? null : odo,
              hmOdo: isAlatBerat ? odo : null,
              fotoStokSolarPath: _fotoStok?.path,
              fotoOdoPagiPath: _fotoOdo?.path,
            );
      _autosaveTimer?.cancel();
      _autosaveTimer = null;
      _autosaveStopped = true;
      try {
        await ChecklistDraftStore.clear(
          armada.id,
          isAkhir: widget.isAkhir,
        );
      } catch (_) {}
      if (!mounted) return;
      AnalyticsService.checklistSubmit(true);
      HapticFeedback.lightImpact();
      if (widget.isAkhir && !delivered) {
        ChecklistDraftStore.markAkhirSubmitted(armada.id).ignore();
      }
      ref.invalidate(checklistAkhirDoneProvider(armada.id));
      ref.invalidate(checklistHariIniProvider);
      _snack(
        delivered
            ? (widget.isAkhir
                  ? 'Checklist akhir berhasil disimpan.'
                  : 'Checklist awal berhasil disimpan.')
            : kCopyQueued,
      );
      if (context.mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) {
        _snack(
          friendlyErrorMessage(
            e,
            fallback: 'Gagal menyimpan checklist. Periksa koneksi lalu coba lagi.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final diperiksa = _bagian.where((b) => b.level != null).length;
    final stokOpsi =
        widget.item?.opsiStokSolar.isNotEmpty == true
            ? widget.item!.opsiStokSolar
            : _stokSolarFallback;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_draftFound) ...[
          DraftRestoreBanner(
            savedAt: _draftSavedAt ?? DateTime.now(),
            onContinue: _continueDraft,
            onDiscard: _discardDraft,
          ),
          const SizedBox(height: 12),
        ],
        if (_readOnly) _LockedBanner(isAkhir: widget.isAkhir, alasan: _lockReason),
        if (_readOnly) const SizedBox(height: 12),
        _SectionCard(
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
              DropdownButtonFormField<String>(
                initialValue: _stokSolar,
                decoration: const InputDecoration(
                  labelText: 'Stok Solar (indikator)',
                  border: OutlineInputBorder(),
                  helperText:
                      'Perkiraan isi tangki berdasarkan indikator bahan bakar (bukan liter)',
                ),
                items: stokOpsi
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.value,
                        child: Text(o.label),
                      ),
                    )
                    .toList(),
                onChanged: _readOnly
                    ? null
                    : (v) {
                        if (v == _stokSolar) return;
                        setState(() => _stokSolar = v);
                        _scheduleAutosave();
                      },
              ),
              const SizedBox(height: 10),
              _PhotoField(
                label: 'Foto indikator stok solar (wajib)',
                localPath: _fotoStok?.path,
                hasExisting: _fotoStokUrl != null,
                enabled: !_readOnly,
                onTap: () => _pickFoto(_FotoSlot.stokSolar),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _odoCtrl,
                enabled: !_readOnly,
                onChanged: _readOnly ? null : (_) => _scheduleAutosave(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: widget.armada.isAlatBerat
                      ? 'HM (Jam Kerja Unit)'
                      : 'ODO (Odometer km)',
                  border: const OutlineInputBorder(),
                  helperText: widget.armada.isAlatBerat
                      ? 'Perkiraan jam kerja unit (bukan km)'
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _odoCtrl,
                builder: (context, value, _) {
                  final current = double.tryParse(value.text.trim());
                  final previous = widget.armada.isAlatBerat
                      ? widget.armada.jamOperasionalTerkini
                      : widget.armada.odoTerkini;
                  return _OdoCompare(
                    isAlatBerat: widget.armada.isAlatBerat,
                    reading: OdoReading(previous: previous, current: current),
                  );
                },
              ),
              const SizedBox(height: 10),
              _PhotoField(
                label: widget.armada.isAlatBerat
                    ? 'Foto HM (wajib)'
                    : 'Foto ODO (wajib)',
                localPath: _fotoOdo?.path,
                hasExisting: _fotoOdoUrl != null,
                enabled: !_readOnly,
                onTap: () => _pickFoto(_FotoSlot.odo),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Pemeriksaan bagian',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '$diperiksa/${_bagian.length} bagian diperiksa',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: diperiksa == _bagian.length
                    ? context.colors.success
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _bagian.length; i++) ...[
          _BagianAccordion(
            state: _bagian[i],
            expanded: _expanded == i,
            readOnly: _readOnly,
            catatanCtrl: _catatanCtrl[i],
            onToggle: () => setState(
              () => _expanded = _expanded == i ? null : i,
            ),
            onLevelChanged: (level) => _setLevel(i, level),
            onFoto: () => _pickItemFoto(i),
            onCatatanChanged: _scheduleAutosave,
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        if (!_readOnly)
          SizedBox(
            height: 48,
            child: BouncingButton(
              onPressed: _busy ? null : _submit,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Menyimpan...'
                      : _isEdit
                      ? 'Simpan Perubahan'
                      : 'Kirim Checklist',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LockedBanner extends StatelessWidget {
  const _LockedBanner({
    required this.isAkhir,
    required this.alasan,
  });

  final bool isAkhir;
  final String? alasan;

  @override
  Widget build(BuildContext context) {
    final text = isAkhir
        ? 'Checklist akhir sudah dikirim dan bersifat final.'
        : (alasan ?? 'Checklist awal sudah terkunci dan tidak bisa diubah.');
    final warna = context.colors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warna.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: warna, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _BagianAccordion extends StatelessWidget {
  const _BagianAccordion({
    required this.state,
    required this.expanded,
    required this.readOnly,
    required this.catatanCtrl,
    required this.onToggle,
    required this.onLevelChanged,
    required this.onFoto,
    required this.onCatatanChanged,
  });

  final _BagianState state;
  final bool expanded;
  final bool readOnly;
  final TextEditingController catatanCtrl;
  final VoidCallback onToggle;
  final ValueChanged<ChecklistItemLevel> onLevelChanged;
  final VoidCallback onFoto;
  final VoidCallback onCatatanChanged;

  /// True bila kondisi bermasalah tapi dokumentasi (catatan/foto) belum
  /// lengkap - dipakai untuk indikator peringatan di header accordion.
  bool get _docIncomplete {
    if (readOnly) return false;
    final level = state.level;
    if (level == null || !level.isBermasalah) return false;
    final hasFoto = state.fotoPath != null && state.fotoPath!.isNotEmpty;
    return catatanCtrl.text.trim().isEmpty || !hasFoto;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: readOnly ? null : onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.bagian,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (_docIncomplete) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: context.colors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Dokumentasi belum lengkap',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  _LevelChip(level: state.level),
                  if (!readOnly) ...[
                    const SizedBox(width: 6),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: context.colors.textMuted,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: context.colors.border),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ToggleChip(
                          label: ChecklistItemLevel.baik.label,
                          selected:
                              state.level == ChecklistItemLevel.baik,
                          selectedColor: context.colors.success,
                          onTap: () => onLevelChanged(ChecklistItemLevel.baik),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleChip(
                          label: ChecklistItemLevel.perluPerhatian.label,
                          selected:
                              state.level ==
                              ChecklistItemLevel.perluPerhatian,
                          selectedColor: context.colors.warning,
                          onTap: () =>
                              onLevelChanged(ChecklistItemLevel.perluPerhatian),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleChip(
                          label: ChecklistItemLevel.rusak.label,
                          selected: state.level == ChecklistItemLevel.rusak,
                          selectedColor: context.colors.error,
                          onTap: () => onLevelChanged(ChecklistItemLevel.rusak),
                        ),
                      ),
                    ],
                  ),
                  if (state.level != null && state.level!.isBermasalah) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: catatanCtrl,
                      maxLines: 2,
                      onChanged: (v) {
                        state.catatan = v;
                        onCatatanChanged();
                      },
                      decoration: InputDecoration(
                        labelText: 'Jelaskan kondisi (wajib)',
                        border: const OutlineInputBorder(),
                        hintText: state.level == ChecklistItemLevel.rusak
                            ? 'Contoh: rem tidak pakem saat mengerem'
                            : 'Contoh: suara mesin kasar',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PhotoField(
                      label: state.level == ChecklistItemLevel.rusak
                          ? 'Foto kerusakan (wajib)'
                          : 'Foto kondisi (wajib)',
                      localPath: state.fotoPath,
                      hasExisting: false,
                      enabled: true,
                      onTap: onFoto,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level});

  final ChecklistItemLevel? level;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (level) {
      ChecklistItemLevel.baik => (level!.label, context.colors.success),
      ChecklistItemLevel.perluPerhatian => (
        level!.label,
        context.colors.warning,
      ),
      ChecklistItemLevel.rusak => (level!.label, context.colors.error),
      null => ('Belum dipilih', context.colors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.label,
    required this.localPath,
    required this.hasExisting,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String? localPath;
  final bool hasExisting;
  final bool enabled;
  final VoidCallback onTap;

  bool get _hasLocal => localPath != null && localPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tersedia = _hasLocal || hasExisting;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tersedia
                ? context.colors.success.withValues(alpha: 0.5)
                : context.colors.border,
          ),
        ),
        child: Row(
          children: [
            if (_hasLocal && File(localPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(localPath!),
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              )
            else
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  tersedia
                      ? Icons.check_circle_outline
                      : Icons.camera_alt_outlined,
                  color: tersedia
                      ? context.colors.success
                      : context.colors.textTertiary,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tersedia ? '$label — foto tersedia' : '$label — ketuk untuk ambil',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            if (enabled)
              Icon(
                Icons.camera_alt_outlined,
                size: 18,
                color: context.colors.primary,
              ),
          ],
        ),
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
    if (reading.previous == null) return const SizedBox.shrink();

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
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
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
            'Sebelumnya: $sebelumnya · Sekarang: '
            '${isAlatBerat ? fmtJam(reading.current) : fmtKm(reading.current)}',
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
          const SizedBox(height: 4),
          if (reading.decreased)
            Text(
              'Perhatian: nilai $satuan ini lebih kecil dari bacaan sebelumnya '
              '(selisih $deltaLbl). Pastikan angka sudah benar.',
              style: TextStyle(fontSize: 12, color: context.colors.error),
            )
          else
            Text(
              'Pemakaian: $deltaLbl',
              style: TextStyle(fontSize: 12, color: context.colors.success),
            ),
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

String _fmtNum(double? n) {
  if (n == null) return '';
  return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);
}
