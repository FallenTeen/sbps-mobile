import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/draft/autosave_controller.dart';
import '../../core/draft/draft_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/draft_restore_banner.dart';
import 'armada_providers.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';

/// Simplified Ajuan Servis Sheet (Fase 2) - Converted from full screen to sheet
/// Form sederhana: pilih armada, kategori, keluhan. 
/// Simplified to ≤3 fields for sheet pattern (removed ODO/Jam fields as optional).
class AjuanServisSheet extends ConsumerStatefulWidget {
  const AjuanServisSheet({super.key, this.initialArmadaId});

  final String? initialArmadaId;

  @override
  ConsumerState<AjuanServisSheet> createState() => _AjuanServisSheetState();
}

class _AjuanServisSheetState extends ConsumerState<AjuanServisSheet> {
  final _formKey = GlobalKey<FormState>();
  final _keluhanController = TextEditingController();

  MasterArmada? _selectedArmada;
  String _kategori = 'rutin';
  bool _isLoading = false;
  bool _initialized = false;
  bool _draftFound = false;
  DateTime? _draftSavedAt;

  late final AutosaveController _autosave;

  String get _draftKey =>
      'servis_ajuan_${widget.initialArmadaId ?? 'new'}';

  Map<String, dynamic> _snapshot() => {
    'armadaId': _selectedArmada?.id,
    'kategori': _kategori,
    'keluhan': _keluhanController.text,
  };

  void _restoreFromDraft(FormDraft draft) {
    final fields = draft.fieldsJson;
    _keluhanController.text = fields['keluhan'] as String? ?? '';
    if (fields['kategori'] is String) _kategori = fields['kategori']!;
    // Armada restore dilakukan saat data masterArmada sudah dimuat
    final armadaId = fields['armadaId'] as String?;
    if (armadaId != null) {
      final armadaList = ref.read(masterArmadaProvider).value;
      if (armadaList != null) {
        final match = armadaList.where((a) => a.id == armadaId).toList();
        if (match.isNotEmpty) setState(() => _selectedArmada = match.first);
      }
    }
    setState(() { _draftFound = true; _draftSavedAt = draft.savedAt; });
  }

  final List<String> _kategoriOptions = const [
    'rutin',
    'kerusakan',
    'darurat',
    'ganti_oli',
  ];

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _autosave.load();
      if (widget.initialArmadaId != null) _prefillArmada();
    });
  }

  void _prefillArmada() {
    final armadaList = ref.read(masterArmadaProvider).value;
    if (armadaList == null || _initialized) return;
    _initialized = true;
    final match = armadaList.where((a) => a.id == widget.initialArmadaId).toList();
    if (match.isNotEmpty) {
      setState(() => _selectedArmada = match.first);
    }
  }

  @override
  void dispose() {
    _autosave.dispose();
    _keluhanController.dispose();
    super.dispose();
  }

  String _formatKategori(String k) {
    return switch (k) {
      'rutin' => 'Servis Rutin / Berkala',
      'kerusakan' => 'Perbaikan Kerusakan',
      'darurat' => 'Darurat / Mogok',
      'ganti_oli' => 'Ganti Oli / Pelumas',
      _ => k,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedArmada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih armada terlebih dahulu')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      await ref.read(servisRepositoryProvider).submitAjuanServis(
            armadaId: _selectedArmada!.id,
            keluhan: _keluhanController.text.trim(),
            kategori: _kategori,
            odometerSaatAjuan: null, // Simplified - optional
            jamOperasionalSaatAjuan: null, // Simplified - optional
          );

      AnalyticsService.servisAjuanSubmit();
      await _autosave.clear();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan servis berhasil dikirim')),
      );

      ref.read(servisRiwayatProvider.notifier).refresh();
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
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

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pengajuan Servis',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_draftFound)
                DraftRestoreBanner(
                  savedAt: _draftSavedAt ?? DateTime.now(),
                  onContinue: () => setState(() => _draftFound = false),
                  onDiscard: () async {
                    await _autosave.clear();
                    setState(() {
                      _draftFound = false;
                      _keluhanController.clear();
                      _selectedArmada = null;
                      _kategori = 'rutin';
                    });
                  },
                ),
              // Content
              Expanded(
                child: masterArmadaAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
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
                    _prefillArmada();
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

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Form(
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
                                _autosave.onFieldChanged();
                              },
                              validator: (val) => val == null ? 'Pilih armada' : null,
                            ),
                            const SizedBox(height: 16),

                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Kategori Servis',
                                border: OutlineInputBorder(),
                                helperText:
                                    'Rutin = servis terjadwal. Darurat = unit mogok, prioritas tertinggi. Ganti Oli = servis ringan.',
                              ),
                              initialValue: _kategori,
                              items: _kategoriOptions.map((k) {
                                return DropdownMenuItem(
                                  value: k,
                                  child: Text(_formatKategori(k)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _kategori = val);
                                _autosave.onFieldChanged();
                              },
                            ),
                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _keluhanController,
                              decoration: const InputDecoration(
                                labelText: 'Keluhan / Deskripsi Masalah',
                                hintText:
                                    'Contoh: mesin berisik saat jalan, rem kurang pakem, oli bocor',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                              maxLines: 4,
                              minLines: 3,
                              validator: (val) => (val == null || val.trim().isEmpty)
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
                                            SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2, color: Colors.white),
                                            ),
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
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
