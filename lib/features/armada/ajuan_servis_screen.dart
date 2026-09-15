import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import 'armada_providers.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Form Pengajuan Servis Armada (Section 21 — Bagian 1 Ajuan Driver/PIC).
class AjuanServisScreen extends ConsumerStatefulWidget {
  const AjuanServisScreen({super.key, this.initialArmadaId});

  final String? initialArmadaId;

  @override
  ConsumerState<AjuanServisScreen> createState() => _AjuanServisScreenState();
}

class _AjuanServisScreenState extends ConsumerState<AjuanServisScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keluhanController = TextEditingController();
  final _odoController = TextEditingController();
  final _jamController = TextEditingController();

  MasterArmada? _selectedArmada;
  String _kategori = 'rutin';
  bool _isLoading = false;
  bool _initialized = false;

  final List<String> _kategoriOptions = const [
    'rutin',
    'kerusakan',
    'darurat',
    'ganti_oli',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialArmadaId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillArmada();
      });
    }
  }

  void _prefillArmada() {
    final armadaList = ref.read(masterArmadaProvider).value;
    if (armadaList == null || _initialized) return;
    _initialized = true;
    final match = armadaList
        .where((a) => a.id == widget.initialArmadaId)
        .toList();
    if (match.isNotEmpty) {
      setState(() => _selectedArmada = match.first);
    }
  }

  @override
  void dispose() {
    _keluhanController.dispose();
    _odoController.dispose();
    _jamController.dispose();
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
      final odo = double.tryParse(_odoController.text);
      final jam = double.tryParse(_jamController.text);

      await ref
          .read(servisRepositoryProvider)
          .submitAjuanServis(
            armadaId: _selectedArmada!.id,
            keluhan: _keluhanController.text.trim(),
            kategori: _kategori,
            odometerSaatAjuan: odo,
            jamOperasionalSaatAjuan: jam,
          );

      AnalyticsService.servisAjuanSubmit();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan servis berhasil dikirim')),
      );

      ref.read(servisRiwayatProvider.notifier).refresh();
      Navigator.of(context).pop();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Servis'),
        actions: const [PortalSwitchButton()],
      ),
      body: masterArmadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat data armada',
          subtitle:
              'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(masterArmadaProvider),
        ),
        data: (armadaList) {
          _prefillArmada();
          if (armadaList.isEmpty) {
            return const AppEmptyState(
              icon: Icons.build_outlined,
              title: 'Tidak ada armada yang terdaftar',
              subtitle:
                  'Hubungi admin untuk mendaftarkan unit armada ke sistem.',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
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
                        if (val != null) {
                          final armadaList = ref.read(armadaSayaProvider).value;
                          final armada = armadaList
                              ?.where((a) => a.id == val.id)
                              .firstOrNull;
                          if (armada != null) {
                            if (_odoController.text.isEmpty &&
                                armada.odoTerkini != null) {
                              _odoController.text = armada.odoTerkini
                                  .toString();
                            }
                            if (_jamController.text.isEmpty &&
                                armada.jamOperasionalTerkini != null) {
                              _jamController.text = armada.jamOperasionalTerkini
                                  .toString();
                            }
                          }
                        }
                      });
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
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _odoController,
                          decoration: const InputDecoration(
                            labelText: 'KM Saat Ini (Odometer)',
                            border: OutlineInputBorder(),
                            helperText:
                                'Isi salah satu (KM atau Jam Kerja) sesuai jenis unit — untuk cek riwayat servis terakhir',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _jamController,
                          decoration: const InputDecoration(
                            labelText: 'Jam Kerja Unit (HM)',
                            border: OutlineInputBorder(),
                            helperText: 'Total jam mesin menyala hari ini',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
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
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
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
    );
  }
}
