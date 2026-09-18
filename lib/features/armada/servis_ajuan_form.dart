import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/draft/autosave_controller.dart';
import '../../core/draft/draft_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/draft_restore_banner.dart';
import '../../shared/widgets/submit_spinner.dart';
import 'armada_providers.dart';
import 'models/armada.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';
import 'servis_status.dart';

/// Satu-satunya source of truth form Pengajuan Servis — dipakai oleh
/// [AjuanServisScreen] (full page) maupun [AjuanServisSheet] (bottom sheet)
/// supaya tidak ada implementasi yang saling berbeda.
///
/// Menangani:
/// - pilih armada (master) + konteks unit dari `GET /armada/saya`
///   (tipe unit menentukan satuan ODO/HM yang relevan, sesuai Phase 08);
/// - prefill ODO/HM terkini dari unit;
/// - kategori + keluhan;
/// - autosave draft (server belum diketahui → isi tidak hilang);
/// - submit via repository (tanpa mengubah payload business rule).
class ServisAjuanForm extends ConsumerStatefulWidget {
  const ServisAjuanForm({
    super.key,
    this.initialArmadaId,
    this.scrollController,
    this.onSuccess,
  });

  final String? initialArmadaId;

  /// Controller scroll untuk sheet (DraggableScrollableSheet). Bila null
  /// form memakai scroll internal sendiri.
  final ScrollController? scrollController;

  /// Dipanggil setelah submit berhasil (wrapper memutuskan pop/refresh).
  final VoidCallback? onSuccess;

  @override
  ConsumerState<ServisAjuanForm> createState() => _ServisAjuanFormState();
}

class _ServisAjuanFormState extends ConsumerState<ServisAjuanForm> {
  final _formKey = GlobalKey<FormState>();
  final _keluhanController = TextEditingController();
  final _odoController = TextEditingController();
  final _jamController = TextEditingController();

  MasterArmada? _selectedArmada;
  String _kategori = 'rutin';
  bool _isLoading = false;
  bool _initialized = false;
  bool _draftFound = false;
  DateTime? _draftSavedAt;

  late final AutosaveController _autosave;

  String get _draftKey => 'servis_ajuan_${widget.initialArmadaId ?? 'new'}';

  Map<String, dynamic> _snapshot() => {
    'armadaId': _selectedArmada?.id,
    'kategori': _kategori,
    'keluhan': _keluhanController.text,
    'odo': _odoController.text,
    'jam': _jamController.text,
  };

  void _restoreFromDraft(FormDraft draft) {
    final fields = draft.fieldsJson;
    _keluhanController.text = fields['keluhan'] as String? ?? '';
    if (fields['kategori'] is String) _kategori = fields['kategori']!;
    _odoController.text = fields['odo'] as String? ?? '';
    _jamController.text = fields['jam'] as String? ?? '';
    // Armada restore dilakukan saat data masterArmada sudah dimuat.
    final armadaId = fields['armadaId'] as String?;
    if (armadaId != null) {
      final armadaList = ref.read(masterArmadaProvider).value;
      if (armadaList != null) {
        final match = armadaList.where((a) => a.id == armadaId).toList();
        if (match.isNotEmpty) setState(() => _selectedArmada = match.first);
      }
    }
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
      draftKey: _draftKey,
      formType: DraftFormType.servisAjuan,
      currentFields: _snapshot,
      onRestore: _restoreFromDraft,
    );
    _autosave.init();

    _keluhanController.addListener(_autosave.onFieldChanged);
    _odoController.addListener(_autosave.onFieldChanged);
    _jamController.addListener(_autosave.onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _autosave.load();
      if (widget.initialArmadaId != null) _ensureArmadaContext();
    });
  }

  /// Prefill armada terpilih (dari query atau draft) sampai punya unit context.
  void _ensureArmadaContext() {
    final armadaList = ref.read(masterArmadaProvider).value;
    if (armadaList == null || _initialized) return;
    _initialized = true;
    final id = widget.initialArmadaId;
    if (id != null) {
      final match = armadaList.where((a) => a.id == id).toList();
      if (match.isNotEmpty) {
        setState(() {
          _selectedArmada = match.first;
          _prefillUnitValues(match.first);
        });
      }
    }
  }

  /// Isi KM/HM terkini dari unit yang dipilih (konteks armadaSaya).
  void _prefillUnitValues(MasterArmada armada) {
    final unit = _unitFor(armada);
    if (unit == null) return;
    if (!unit.isAlatBerat) {
      if (_odoController.text.trim().isEmpty && unit.odoTerkini != null) {
        _odoController.text = _fmtReading(unit.odoTerkini!);
      }
    } else {
      if (_jamController.text.trim().isEmpty &&
          unit.jamOperasionalTerkini != null) {
        _jamController.text = _fmtReading(unit.jamOperasionalTerkini!);
      }
    }
  }

  static String _fmtReading(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  /// Unit konteks (dari `/armada/saya`) yang cocok dengan [armada].
  ArmadaSaya? _unitFor(MasterArmada armada) {
    final units = ref.read(armadaSayaProvider).value;
    if (units == null) return null;
    for (final u in units) {
      if (u.id == armada.id) return u;
    }
    return null;
  }

  @override
  void dispose() {
    _autosave.dispose();
    _keluhanController.dispose();
    _odoController.dispose();
    _jamController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArmada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih armada terlebih dahulu')),
      );
      return;
    }

    final odoText = _odoController.text.trim();
    final jamText = _jamController.text.trim();
    if (odoText.isEmpty && jamText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Isi KM atau Jam Kerja Unit sesuai jenis kendaraan Anda',
          ),
        ),
      );
      return;
    }

    final odo = odoText.isEmpty ? null : double.tryParse(odoText);
    final jam = jamText.isEmpty ? null : double.tryParse(jamText);
    if ((odoText.isNotEmpty && odo == null) ||
        (jamText.isNotEmpty && jam == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Format angka tidak valid')));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final result = await ref
          .read(servisRepositoryProvider)
          .submitAjuanServis(
            armadaId: _selectedArmada!.id,
            keluhan: _keluhanController.text.trim(),
            kategori: _kategori,
            odometerSaatAjuan: odo,
            jamOperasionalSaatAjuan: jam,
          );

      AnalyticsService.servisAjuanSubmit();
      // Data kini tersimpan aman (di server ATAU di outbox) — draft tidak
      // lagi dibutuhkan. Queued != Synced: snackbar membedakan keduanya.
      await _autosave.clear();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.delivered
                ? 'Pengajuan servis berhasil dikirim'
                : kCopyQueued,
          ),
        ),
      );

      ref.read(servisRiwayatProvider.notifier).refresh();
      widget.onSuccess?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal mengajukan servis.\nPeriksa koneksi lalu coba lagi.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterArmadaAsync = ref.watch(masterArmadaProvider);

    return masterArmadaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text('Gagal memuat data armada'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(masterArmadaProvider),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
      data: (armadaList) {
        _ensureArmadaContext();
        if (armadaList.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.build_outlined, size: 48),
                SizedBox(height: 12),
                Text('Tidak ada armada yang terdaftar'),
              ],
            ),
          );
        }

        final unitContext = _selectedArmada == null
            ? null
            : _unitFor(_selectedArmada!);

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            if (_draftFound)
              DraftRestoreBanner(
                savedAt: _draftSavedAt ?? DateTime.now(),
                onContinue: () => setState(() => _draftFound = false),
                onDiscard: () async {
                  await _autosave.clear();
                  setState(() {
                    _draftFound = false;
                    _keluhanController.clear();
                    _odoController.clear();
                    _jamController.clear();
                    _selectedArmada = null;
                    _kategori = 'rutin';
                  });
                },
              ),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<MasterArmada>(
                    decoration: const InputDecoration(
                      labelText: 'Pilih Armada *',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedArmada,
                    items: armadaList.map((armada) {
                      final label = [
                        armada.platNomor,
                        if (armada.kodeUnit != null) armada.kodeUnit!,
                        if (armada.jenis != null) armada.jenis!,
                      ].join(' - ');
                      return DropdownMenuItem(
                        value: armada,
                        child: Text(label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedArmada = val;
                        _draftFound = false;
                      });
                      if (val != null) _prefillUnitValues(val);
                      _autosave.onFieldChanged();
                    },
                    validator: (val) => val == null ? 'Pilih armada' : null,
                  ),
                  const SizedBox(height: 16),

                  // Konteks unit: tipe menentukan satuan ODO/HM yang relevan.
                  if (unitContext != null) ...[
                    _UnitTypeBanner(isAlatBerat: unitContext.isAlatBerat),
                    const SizedBox(height: 16),
                    if (unitContext.isAlatBerat)
                      TextFormField(
                        controller: _jamController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Jam Kerja Unit (HM)',
                          border: OutlineInputBorder(),
                          helperText:
                              'Total jam mesin menyala dari Hour Meter',
                          prefixIcon: Icon(Icons.timer_outlined),
                        ),
                        onChanged: (_) => _autosave.onFieldChanged(),
                      )
                    else
                      TextFormField(
                        controller: _odoController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'KM Saat Ini (Odometer)',
                          border: OutlineInputBorder(),
                          helperText:
                              'Angka pada odometer untuk cek riwayat servis',
                          prefixIcon: Icon(Icons.speed_outlined),
                        ),
                        onChanged: (_) => _autosave.onFieldChanged(),
                      ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _odoController,
                            decoration: const InputDecoration(
                              labelText: 'KM Saat Ini (Odometer)',
                              border: OutlineInputBorder(),
                              helperText: 'Untuk unit kendaraan',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _autosave.onFieldChanged(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _jamController,
                            decoration: const InputDecoration(
                              labelText: 'Jam Kerja Unit (HM)',
                              border: OutlineInputBorder(),
                              helperText: 'Untuk alat berat',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => _autosave.onFieldChanged(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Kategori Servis',
                      border: OutlineInputBorder(),
                      helperText:
                          'Rutin = servis terjadwal. Darurat = unit mogok, '
                          'prioritas tertinggi. Ganti Oli = servis ringan.',
                    ),
                    initialValue: _kategori,
                    items: kKategoriServisOptions.map((k) {
                      return DropdownMenuItem(
                        value: k,
                        child: Text(formatKategoriServis(k)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _kategori = val);
                      }
                      _autosave.onFieldChanged();
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _keluhanController,
                    decoration: const InputDecoration(
                      labelText: 'Keluhan / Deskripsi Masalah',
                      hintText:
                          'Contoh: mesin berisik saat jalan, rem kurang pakem, '
                          'oli bocor',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    minLines: 3,
                    validator: (val) =>
                        (val == null || val.trim().isEmpty)
                        ? 'Keluhan wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: BouncingButton(
                      onPressed: _isLoading ? null : _submit,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SubmitSpinner(size: 18),
                                  SizedBox(width: 8),
                                  Text('Mengirim...'),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.send_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Kirim Pengajuan Servis'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Banner tipe unit — dipakai form servis supaya konteks ODO/HM jelas,
/// konsisten dengan pola OdoAwalScreen (Phase 08).
class _UnitTypeBanner extends StatelessWidget {
  const _UnitTypeBanner({required this.isAlatBerat});

  final bool isAlatBerat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            isAlatBerat ? Icons.construction : Icons.speed_outlined,
            color: context.colors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAlatBerat
                  ? 'Alat Berat — nilai dalam HM (jam mesin)'
                  : 'Kendaraan — nilai dalam KM (odometer)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}