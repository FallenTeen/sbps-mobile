import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

/// Input ritase ringkas untuk Driver (Section 21.4):
/// Driver mencatat jumlah rit dan satuan dari lapangan.
class RitaseInputScreen extends ConsumerStatefulWidget {
  const RitaseInputScreen({super.key});

  @override
  ConsumerState<RitaseInputScreen> createState() => _RitaseInputScreenState();
}

class _RitaseInputScreenState extends ConsumerState<RitaseInputScreen> {
  ArmadaSaya? _selectedArmada;
  final _jumlahRitCtrl = TextEditingController();
  final _satuanCtrl = TextEditingController(text: 'rit');
  final _catatanCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _jumlahRitCtrl.dispose();
    _satuanCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedArmada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kendaraan terlebih dahulu')),
      );
      return;
    }

    final jumlah = int.tryParse(_jumlahRitCtrl.text.trim());
    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah rit harus angka positif')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Kirim ke backend POST /armada/ritase/input
      // Untuk sekarang, tampilkan success message
      await Future<void>.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ritase tersimpan: $jumlah ${_satuanCtrl.text}'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan ritase')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Ritase'),
        actions: const [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat armada: $e')),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const Center(
              child: Text('Tidak ada armada yang sedang Anda pegang.'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pilih kendaraan
                Text('Kendaraan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const SizedBox(height: 8),
                DropdownButtonFormField<ArmadaSaya>(
                  decoration: const InputDecoration(
                    labelText: 'Pilih Kendaraan',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedArmada,
                  items: armadaList.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text('${a.platNomor} — ${a.jenis ?? 'N/A'}'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedArmada = v),
                ),
                const SizedBox(height: 24),

                // Jumlah rit
                Text('Jumlah Rit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _jumlahRitCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Jumlah',
                          border: OutlineInputBorder(),
                          suffixText: 'rit',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _satuanCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Satuan',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Catatan (opsional)
                TextField(
                  controller: _catatanCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Simpan Ritase'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
