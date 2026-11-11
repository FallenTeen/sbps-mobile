import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/draft/autosave_controller.dart';
import '../../core/draft/draft_repository.dart';
import '../../core/formatters.dart';
import '../../core/watermark_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/draft_restore_banner.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/submit_spinner.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

/// Pengisian Solar (langkah 02) — catat pengisian bahan bakar hari ini.
///
/// Opional: tidak menghalangi langkah berikutnya. Daftar menampilkan riwayat
/// pengisian hari ini; form mencatat ODO/HM saat isi (+foto), liter, nominal
/// Rp, Rp/L otomatis (read-only), foto nota, dan catatan.
class PengisianSolarScreen extends ConsumerStatefulWidget {
  const PengisianSolarScreen({super.key});

  @override
  ConsumerState<PengisianSolarScreen> createState() =>
      _PengisianSolarScreenState();
}

class _PengisianSolarScreenState extends ConsumerState<PengisianSolarScreen> {
  ArmadaSaya? _selectedArmada;

  void _applySingle(List<ArmadaSaya> list) {
    if (list.length == 1 && _selectedArmada?.id != list.first.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedArmada?.id != list.first.id) {
          setState(() => _selectedArmada = list.first);
        }
      });
    }
  }

  Future<void> _openForm(ArmadaSaya armada) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PengisianFormSheet(armada: armada),
    );
    if (result == true && mounted) {
      ref.invalidate(checklistHariIniProvider);
      ref.invalidate(armadaSayaProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);
    final checklistAsync = ref.watch(checklistHariIniProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Pengisian Solar'),
        actions: const [PortalSwitchButton()],
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
              icon: Icons.local_gas_station_outlined,
              title: 'Belum ada unit yang ditugaskan',
              subtitle: 'Hubungi admin untuk penugasan unit.',
            );
          }
          _applySingle(armadaList);
          final armada = armadaList.length == 1
              ? armadaList.first
              : _selectedArmada;

          final checklists = checklistAsync.value ?? const <ArmadaChecklist>[];
          final pengisian = armada == null
              ? const <PengisianSolarItem>[]
              : (checklists
                        .where((c) => c.armadaId == armada.id)
                        .firstOrNull
                        ?.pengisian ??
                    const <PengisianSolarItem>[]);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (armadaList.length > 1) ...[
                _unitDropdown(armadaList),
                const SizedBox(height: 16),
              ],
              if (armada != null) ...[
                _ArmadaInfo(armada: armada),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BouncingButton(
                    onPressed: () => _openForm(armada),
                    child: FilledButton.icon(
                      onPressed: () => _openForm(armada),
                      icon: const Icon(Icons.local_gas_station_outlined),
                      label: const Text('Catat Pengisian'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pengisian Hari Ini',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                if (checklistAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _PengisianList(items: pengisian),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _unitDropdown(List<ArmadaSaya> armadaList) {
    return DropdownButtonFormField<ArmadaSaya>(
      initialValue: _selectedArmada,
      decoration: const InputDecoration(
        labelText: 'Pilih Kendaraan',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.local_shipping_outlined),
        helperText: 'Pilih unit yang Anda operasikan hari ini',
      ),
      items: armadaList
          .map(
            (a) => DropdownMenuItem(
              value: a,
              child: Text('${a.platNomor} — ${a.jenis ?? a.kodeUnit ?? ''}'),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedArmada = v);
      },
    );
  }
}

class _ArmadaInfo extends StatelessWidget {
  const _ArmadaInfo({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final bagian = [
      armada.platNomor,
      if (armada.kodeUnit != null) armada.kodeUnit!,
      if (armada.jenis != null) armada.jenis!,
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
              bagian,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PengisianList extends StatelessWidget {
  const _PengisianList({required this.items});

  final List<PengisianSolarItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(
          'Belum ada pengisian solar hari ini.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.textTertiary, fontSize: 13),
        ),
      );
    }
    return Column(
      children: [for (final p in items) _PengisianCard(item: p)],
    );
  }
}

class _PengisianCard extends StatelessWidget {
  const _PengisianCard({required this.item});

  final PengisianSolarItem item;

  @override
  Widget build(BuildContext context) {
    final hasNota = item.notaLengkap == true ||
        (item.fotoNotaUrl != null && item.fotoNotaUrl!.isNotEmpty);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_gas_station,
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _fmtJam(pengisian: item.waktu),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (item.tanggal != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '• ${item.tanggal}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  fmtRp(item.nominalRp ?? 0),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  'ODO/HM: ${_fmtNum(item.odoAtauHm)}',
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                ),
                if (!hasNota) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: context.colors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 12,
                          color: context.colors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Nota belum lengkap',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.colors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (item.catatan != null && item.catatan!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.catatan!,
                style: TextStyle(fontSize: 12, color: context.colors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PengisianFormSheet extends ConsumerStatefulWidget {
  const _PengisianFormSheet({required this.armada});

  final ArmadaSaya armada;

  @override
  ConsumerState<_PengisianFormSheet> createState() =>
      _PengisianFormSheetState();
}

class _PengisianFormSheetState extends ConsumerState<_PengisianFormSheet> {
  final _odoCtrl = TextEditingController();
  final _nominalCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  CapturedPhoto? _fotoOdo;
  CapturedPhoto? _fotoNota;
  bool _isLoading = false;
  bool _submitted = false;
  bool _draftFound = false;
  DateTime? _draftSavedAt;
  String? _prefilledOdo;
  late final AutosaveController _autosave;

  String get _draftKey => 'pengisian_solar_${widget.armada.id}';

  Map<String, dynamic> _snapshot() => {
    'odo': _odoCtrl.text,
    'nominal': _nominalCtrl.text,
    'catatan': _catatanCtrl.text,
    'fotoOdo': _fotoOdo?.path,
    'fotoNota': _fotoNota?.path,
  };

  void _restoreFromDraft(FormDraft draft) {
    final f = draft.fieldsJson;
    final odo = f['odo']?.toString() ?? '';
    final nominal = f['nominal']?.toString() ?? '';
    final catatan = f['catatan']?.toString() ?? '';
    final fotoOdoPath = f['fotoOdo']?.toString();
    final fotoNotaPath = f['fotoNota']?.toString();
    final hasOdoFoto =
        fotoOdoPath != null &&
        fotoOdoPath.isNotEmpty &&
        File(fotoOdoPath).existsSync();
    final hasNotaFoto =
        fotoNotaPath != null &&
        fotoNotaPath.isNotEmpty &&
        File(fotoNotaPath).existsSync();
    // Draft yang hanya berisi nilai prefill (tidak ada input user) tidak
    // perlu ditawarkan — hindari banner "Lanjutkan?" yang tidak berguna.
    final meaningful =
        nominal.trim().isNotEmpty ||
        catatan.trim().isNotEmpty ||
        hasOdoFoto ||
        hasNotaFoto ||
        (odo.trim().isNotEmpty && odo != (_prefilledOdo ?? ''));
    if (!meaningful) {
      _autosave.clear();
      return;
    }
    setState(() {
      if (odo.isNotEmpty) _odoCtrl.text = odo;
      if (nominal.isNotEmpty) _nominalCtrl.text = nominal;
      if (catatan.isNotEmpty) _catatanCtrl.text = catatan;
      if (hasOdoFoto) {
        _fotoOdo = CapturedPhoto(
          path: fotoOdoPath,
          gpsStatus: GpsStatus.unavailable,
          latitude: null,
          longitude: null,
        );
      }
      if (hasNotaFoto) {
        _fotoNota = CapturedPhoto(
          path: fotoNotaPath,
          gpsStatus: GpsStatus.unavailable,
          latitude: null,
          longitude: null,
        );
      }
      _draftFound = true;
      _draftSavedAt = draft.savedAt;
    });
  }

  @override
  void initState() {
    super.initState();
    final odo = widget.armada.isAlatBerat
        ? widget.armada.jamOperasionalTerkini
        : widget.armada.odoTerkini;
    if (odo != null) _odoCtrl.text = _fmtNum(odo);
    _prefilledOdo = _odoCtrl.text;
    _autosave = AutosaveController(
      ref: ref,
      draftKey: _draftKey,
      formType: DraftFormType.pengisianSolar,
      currentFields: _snapshot,
      currentPhotoPaths: () => [
        if (_fotoOdo != null) _fotoOdo!.path,
        if (_fotoNota != null) _fotoNota!.path,
      ],
      onRestore: _restoreFromDraft,
    );
    _autosave.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autosave.load();
    });
  }

  @override
  void dispose() {
    if (!_submitted) _autosave.flush();
    _autosave.dispose();
    _odoCtrl.dispose();
    _nominalCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  double? get _nominal => double.tryParse(_nominalCtrl.text.trim());

  Future<void> _pickFoto({required bool isOdo}) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null || !mounted) return;
    setState(() {
      if (isOdo) {
        _fotoOdo = photo;
      } else {
        _fotoNota = photo;
      }
    });
    _autosave.onFieldChanged();
  }

  Future<void> _submit() async {
    final odo = double.tryParse(_odoCtrl.text.trim());
    final nominal = _nominal;
    if (odo == null) {
      _snack(widget.armada.isAlatBerat
          ? 'HM saat isi wajib diisi.'
          : 'ODO saat isi wajib diisi.');
      return;
    }
    if (nominal == null || nominal <= 0) {
      _snack('Nominal Rp harus diisi dan lebih dari 0.');
      return;
    }
    if (_fotoOdo == null) {
      _snack('Foto ODO/HM saat isi wajib diambil dari kamera.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final delivered = await ref
          .read(armadaRepositoryProvider)
          .submitPengisianSolar(
            armadaId: widget.armada.id,
            odoAtauHm: odo,
            nominalRp: nominal,
            fotoOdoPath: _fotoOdo!.path,
            fotoNotaPath: _fotoNota?.path,
            catatan: _catatanCtrl.text,
          );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _snack(delivered ? 'Pengisian solar tersimpan.' : kCopyQueued);
      _submitted = true;
      final navigator = Navigator.of(context);
      await _autosave.clear();
      navigator.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (e) {
      if (!mounted) return;
      _snack(friendlyErrorMessage(e, fallback: 'Gagal menyimpan. Coba lagi.'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final armada = widget.armada;
    final satuan = armada.isAlatBerat ? 'HM' : 'KM';

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Catat Pengisian Solar',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${armada.platNomor}${armada.kodeUnit != null ? ' • ${armada.kodeUnit}' : ''}',
              style: TextStyle(fontSize: 13, color: context.colors.textTertiary),
            ),
            if (_draftFound) ...[
              const SizedBox(height: 12),
              DraftRestoreBanner(
                savedAt: _draftSavedAt ?? DateTime.now(),
                onContinue: () => setState(() => _draftFound = false),
                onDiscard: () async {
                  await _autosave.clear();
                  if (!mounted) return;
                  setState(() {
                    _draftFound = false;
                    if (_prefilledOdo != null) _odoCtrl.text = _prefilledOdo!;
                    _nominalCtrl.clear();
                    _catatanCtrl.clear();
                    _fotoOdo = null;
                    _fotoNota = null;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _odoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _autosave.onFieldChanged(),
              decoration: InputDecoration(
                labelText: armada.isAlatBerat
                    ? 'HM saat isi'
                    : 'ODO saat isi ($satuan)',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  armada.isAlatBerat
                      ? Icons.timer_outlined
                      : Icons.speed_outlined,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nominalCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => _autosave.onFieldChanged(),
              decoration: const InputDecoration(
                labelText: 'Nominal Pembelian',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
                helperText: 'Driver tidak perlu mengisi liter (diisi kantor/nota).',
              ),
            ),
            const SizedBox(height: 16),
            _PhotoField(
              label: armada.isAlatBerat
                  ? 'Foto HM (wajib)'
                  : 'Foto ODO (wajib)',
              photo: _fotoOdo,
              onTap: _isLoading ? null : () => _pickFoto(isOdo: true),
            ),
            const SizedBox(height: 12),
            _PhotoField(
              label: 'Foto Nota (opsional)',
              photo: _fotoNota,
              onTap: _isLoading ? null : () => _pickFoto(isOdo: false),
            ),
            const SizedBox(height: 6),
            Text(
              'Nota boleh diserahkan manual ke Ketua Armada / Keuangan.',
              style: TextStyle(fontSize: 12, color: context.colors.textTertiary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _catatanCtrl,
              maxLines: 2,
              onChanged: (_) => _autosave.onFieldChanged(),
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: BouncingButton(
                onPressed: _isLoading ? null : _submit,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SubmitSpinner()
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Pengisian'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.label,
    required this.photo,
    required this.onTap,
  });

  final String label;
  final CapturedPhoto? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasPhoto
                ? context.colors.success.withValues(alpha: 0.5)
                : context.colors.border,
          ),
        ),
        child: hasPhoto
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(11),
                    ),
                    child: Image.file(
                      File(photo!.path),
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(
                        width: 88,
                        height: 88,
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.check_circle,
                      color: context.colors.success,
                      size: 20,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(
                    Icons.camera_alt_outlined,
                    color: context.colors.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$label — ketuk untuk ambil foto',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String _fmtNum(double? n) {
  if (n == null) return '-';
  return n % 1 == 0 ? fmtRibuan(n.toInt()) : n.toStringAsFixed(1);
}

String _fmtJam({String? pengisian}) {
  if (pengisian == null || pengisian.isEmpty) return '-';
  if (pengisian.length >= 5 && pengisian.contains(':')) {
    return pengisian.substring(0, 5);
  }
  return pengisian;
}
