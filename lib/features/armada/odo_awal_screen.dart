import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

class OdoAwalScreen extends ConsumerStatefulWidget {
  const OdoAwalScreen({super.key});

  @override
  ConsumerState<OdoAwalScreen> createState() => _OdoAwalScreenState();
}

class _OdoAwalScreenState extends ConsumerState<OdoAwalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titikIdController = TextEditingController();
  final _odoAwalController = TextEditingController();

  ArmadaSaya? _selectedArmada;
  bool _isLoading = false;

  @override
  void dispose() {
    _titikIdController.dispose();
    _odoAwalController.dispose();
    super.dispose();
  }

  void _onArmadaChanged(ArmadaSaya? armada) {
    setState(() {
      _selectedArmada = armada;
      if (armada?.titikId != null) {
        _titikIdController.text = armada!.titikId!;
      }
    });
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
      final odoAwal = double.parse(_odoAwalController.text);
      await ref
          .read(armadaRepositoryProvider)
          .submitOdoAwalProyek(
            armadaId: _selectedArmada!.id,
            titikId: _titikIdController.text.trim(),
            odoAwal: odoAwal,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berhasil menyimpan ODO awal')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan yang tidak terduga')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Input ODO Awal')),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Gagal memuat daftar armada: $error')),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const Center(
              child: Text('Tidak ada armada yang sedang Anda pegang.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<ArmadaSaya>(
                    decoration: const InputDecoration(
                      labelText: 'Armada',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedArmada,
                    items: armadaList.map((armada) {
                      return DropdownMenuItem(
                        value: armada,
                        child: Text(
                          '${armada.platNomor} - ${armada.jenis ?? 'Unknown'}',
                        ),
                      );
                    }).toList(),
                    onChanged: _onArmadaChanged,
                    validator: (value) => value == null ? 'Pilih armada' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titikIdController,
                    decoration: const InputDecoration(
                      labelText: 'Titik/Proyek ID',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Titik ID wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _odoAwalController,
                    decoration: const InputDecoration(
                      labelText: 'ODO Awal (KM)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'ODO awal wajib diisi';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Format angka tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Simpan ODO Awal'),
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
