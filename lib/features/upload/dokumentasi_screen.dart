import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/draft/autosave_controller.dart';
import '../../core/draft/draft_repository.dart';
import '../../core/photo_compression_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/draft_restore_banner.dart';
import '../../shared/widgets/form_section.dart';
import '../../shared/widgets/key_value_row.dart';
import '../../shared/widgets/photo_grid_editor.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/sticky_action_bar.dart';
import '../produksi/models/production_session.dart';
import '../produksi/produksi_providers.dart';
import 'upload_providers.dart';

/// Lampirkan dokumentasi foto produksi/QC (Fase A2.7): pilih 1-10 foto,
/// opsional kaitkan ke sesi produksi (subject_type "ProductionSession"),
/// kirim via outbox — offline = antrean otomatis.
class DokumentasiScreen extends ConsumerStatefulWidget {
  const DokumentasiScreen({super.key});

  @override
  ConsumerState<DokumentasiScreen> createState() => _DokumentasiScreenState();
}

class _DokumentasiScreenState extends ConsumerState<DokumentasiScreen> {
  static const _maksFile = 10;

  final List<String> _paths = [];
  final _catatanCtrl = TextEditingController();
  ProductionSession? _sesi;

  bool _draftFound = false;
  DateTime? _draftSavedAt;

  late final AutosaveController _autosave;

  Map<String, dynamic> _snapshot() => {
    'catatan': _catatanCtrl.text,
    'sesiId': _sesi?.id,
  };

  void _restoreFromDraft(FormDraft draft) {
    final fields = draft.fieldsJson;
    _catatanCtrl.text = fields['catatan'] as String? ?? '';
    final sesiId = fields['sesiId'] as String?;
    if (sesiId != null) {
      final sesiAktif =
          ref.read(sesiAktifProvider).value ?? const <ProductionSession>[];
      for (final s in sesiAktif) {
        if (s.id == sesiId) {
          _sesi = s;
          break;
        }
      }
    }
    _paths
      ..clear()
      ..addAll(draft.photoLocalPaths);
    setState(() {
      _draftFound = true;
      _draftSavedAt = draft.savedAt;
    });
  }

  @override
  void initState() {
    super.initState();
    _autosave = AutosaveController(
      ref: ref,
      draftKey: 'dokumentasi_produksi',
      formType: DraftFormType.dokumentasi,
      currentFields: _snapshot,
      currentPhotoPaths: () => List.unmodifiable(_paths),
      onRestore: _restoreFromDraft,
    );
    _autosave.init();
    _catatanCtrl.addListener(_catatanChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autosave.load());
  }

  void _catatanChanged() => _autosave.onFieldChanged();

  void _setFoto(List<String> next) {
    if (!mounted) return;
    setState(() {
      _paths
        ..clear()
        ..addAll(next);
    });
    _autosave.onFieldChanged();
  }

  void _setSesi(ProductionSession? value) {
    setState(() => _sesi = value);
    _autosave.onFieldChanged();
  }

  @override
  void dispose() {
    _autosave.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _paths.isNotEmpty ||
      _catatanCtrl.text.trim().isNotEmpty ||
      _sesi != null;

  Future<void> _confirmDiscardDraft() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Keluar tanpa menyimpan?',
      message:
          'Draft dokumentasi yang belum dikirim akan hilang. Lanjutkan keluar?',
      confirmLabel: 'Ya, Keluar',
      icon: Icons.arrow_back_rounded,
    );
    if (confirm?.confirmed == true && mounted) {
      await _autosave.clear();
      if (!mounted) return;
      context.pop();
    }
  }

  Future<void> _submit() async {
    final result = await ref
        .read(uploadSubmitProvider.notifier)
        .submitDokumentasi(
          photoPaths: List.of(_paths),
          subjectType: _sesi == null ? null : 'ProductionSession',
          subjectId: _sesi?.id,
          catatan: _catatanCtrl.text.trim(),
        );
    await _autosave.clear();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.delivered || result.queued) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.delivered ? 'Dokumentasi berhasil diunggah.' : kCopyQueued,
          ),
        ),
      );
      context.pop();
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  String _submitLabel(UploadPhase? phase) => switch (phase) {
    UploadPhase.compressing => 'Mengompres...',
    UploadPhase.sending => 'Mengirim...',
    _ => 'Unggah Dokumentasi',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = ref.watch(uploadSubmitProvider);
    final sesiAktif = ref.watch(sesiAktifProvider);
    final sesiList = sesiAktif.value ?? const <ProductionSession>[];
    final sesiNama = _sesi == null
        ? 'Tidak dikaitkan'
        : '${_sesi!.produkNama ?? 'Produk'} — ${_sesi!.mesinNama ?? 'Mesin'}';
    final valid = _paths.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumentasi Produksi'),
        actions: const [PortalSwitchButton()],
      ),
      body: PopScope(
        canPop: !_hasDraft,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (busy.busy) return;
          _confirmDiscardDraft();
        },
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  if (_draftFound)
                    DraftRestoreBanner(
                      savedAt: _draftSavedAt ?? DateTime.now(),
                      onContinue: () => setState(() => _draftFound = false),
                      onDiscard: () async {
                        await _autosave.clear();
                        if (!mounted) return;
                        setState(() {
                          _draftFound = false;
                          _catatanCtrl.clear();
                          _sesi = null;
                          _paths.clear();
                        });
                      },
                      warning:
                          'Foto mungkin sudah tidak sesuai kondisi terkini, '
                          'disarankan periksa ulang sebelum mengirim.',
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FormSection(
                      title: 'Konteks',
                      children: [
                        const KeyValueRow(
                          label: 'Jenis',
                          value: 'Dokumentasi Produksi / QC',
                        ),
                        KeyValueRow(
                          label: 'Jumlah Foto',
                          value: '${_paths.length}/$_maksFile',
                          valueIsImportant: true,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FormSection(
                      title: 'Dokumentasi',
                      children: [
                        Text(
                          'Foto hasil kerja di lokasi (minimal 1, maks '
                          '$_maksFile).',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.colors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PhotoGridEditor(
                          paths: _paths,
                          onPathsChanged: _setFoto,
                          maxCount: _maksFile,
                          enabled: !busy.busy,
                          heroTagPrefix: 'dokumentasi_photo',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FormSection(
                      title: 'Kaitkan Sesi',
                      children: [
                        DropdownButtonFormField<ProductionSession>(
                          initialValue: _sesi,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sesi produksi (opsional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final s in sesiList)
                              DropdownMenuItem(
                                value: s,
                                child: Text(
                                  '${s.produkNama ?? 'Produk'} — '
                                  '${s.mesinNama ?? 'Mesin'}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: busy.busy
                              ? null
                              : (v) => _setSesi(v),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FormSection(
                      title: 'Catatan',
                      children: [
                        TextField(
                          controller: _catatanCtrl,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Catatan (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FormSection(
                      title: 'Review',
                      children: [
                        KeyValueRow(
                          label: 'Foto untuk dikirim',
                          value: '${_paths.length}/$_maksFile',
                        ),
                        KeyValueRow(label: 'Sesi produksi', value: sesiNama),
                        KeyValueRow(
                          label: 'Catatan',
                          value: _catatanCtrl.text.trim().isEmpty
                              ? '—'
                              : _catatanCtrl.text.trim(),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              valid
                                  ? Icons.check_circle_outline
                                  : Icons.pending_actions_outlined,
                              size: 18,
                              color: valid
                                  ? context.colors.success
                                  : context.colors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                valid
                                    ? 'Dokumentasi siap dikirim.'
                                    : 'Tambahkan minimal satu foto sebelum mengirim.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Draft tersimpan otomatis di perangkat — aman bila '
                      'aplikasi tertutup.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            StickyActionBar(
              primaryLabel: _submitLabel(busy.phase),
              primaryIcon: Icons.cloud_upload_outlined,
              onPrimary: busy.busy ? () {} : _submit,
              showPrimaryLoading: busy.busy,
            ),
          ],
        ),
      ),
    );
  }
}