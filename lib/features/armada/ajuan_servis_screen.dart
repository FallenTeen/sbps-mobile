import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';

/// Form Pengajuan Servis Armada (Section 21 — Bagian 1 Ajuan Driver/PIC).
class AjuanServisScreen extends ConsumerStatefulWidget {
  const AjuanServisScreen({super.key});

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

  final List<String> _kategoriOptions = const [
    'rutin',
    'kerusakan',
    'darurat',
    'ganti_oli',
  ];

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

    setState(() => _isLoading = true);

    try {
      final odo = double.tryParse(_odoController.text);
      final jam = double.tryParse(_jamController.text);

      await ref.read(servisRepositoryProvider).submitAjuanServis(
            armadaId: _selectedArmada!.id,
            keluhan: _keluhanController.text.trim(),
            kategori: _kategori,
            odometerSaatAjuan: odo,
            jamOperasionalSaatAjuan: jam,
          );

      if (!mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengajukan servis: $e')),
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
      ),
      body: masterArmadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat master armada: $error'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(masterArmadaProvider),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const Center(
              child: Text('Tidak ada armada yang terdaftar.'),
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
                    onChanged: (val) => setState(() => _selectedArmada = val),
                    validator: (val) => val == null ? 'Pilih armada' : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Kategori Servis *',
                      border: OutlineInputBorder(),
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
                            labelText: 'ODO Saat Ini (km)',
                            border: OutlineInputBorder(),
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
                            labelText: 'Jam Operasional',
                            border: OutlineInputBorder(),
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
                      labelText: 'Keluhan / Deskripsi Masalah *',
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

                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Kirim Pengajuan Servis'),
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
