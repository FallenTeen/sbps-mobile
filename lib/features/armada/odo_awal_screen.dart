import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'armada_providers.dart';
import 'models/armada.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// ODO Harian — input odometer sekali per hari.
/// Form tunggal: pilih kendaraan, lihat ODO terakhir, update ODO sekarang.
/// Tidak ada lagi wizard 2-step atau radio "angkutan ke berapa".
class OdoAwalScreen extends ConsumerStatefulWidget {
  const OdoAwalScreen({super.key});

  @override
  ConsumerState<OdoAwalScreen> createState() => _OdoAwalScreenState();
}

class _OdoAwalScreenState extends ConsumerState<OdoAwalScreen> {
  ArmadaSaya? _selectedArmada;
  late TextEditingController _odoController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _odoController = TextEditingController();
  }

  @override
  void dispose() {
    _odoController.dispose();
    super.dispose();
  }

  void _onArmadaChanged(ArmadaSaya? armada) {
    setState(() {
      _selectedArmada = armada;
      // Prefill dengan ODO terkini jika ada
      if (armada?.odoTerkini != null) {
        _odoController.text = armada!.odoTerkini!.toStringAsFixed(0);
      } else {
        _odoController.clear();
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedArmada == null) return;
    if (_odoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ODO harus diisi')),
      );
      return;
    }

    final odoValue = double.tryParse(_odoController.text.trim());
    if (odoValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format angka ODO tidak valid')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final delivered = await ref.read(armadaRepositoryProvider).submitOdoAwalProyek(
        armadaId: _selectedArmada!.id,
        titikId: _selectedArmada!.titikId ?? '',
        odoAwal: odoValue,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(delivered
              ? 'ODO terkini berhasil diperbarui'
              : 'Tersimpan. Menunggu sinkronisasi saat online.'),
        ),
      );
      context.go('/armada/unit-saya');
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
      appBar: AppBar(
        title: const Text('ODO Harian'),
        actions: const [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat data: $error')),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const AppEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Tidak ada armada',
              subtitle: 'Anda belum memiliki armada yang ditugaskan.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Dropdown kendaraan
              DropdownButtonFormField<ArmadaSaya>(
                initialValue: _selectedArmada,
                decoration: const InputDecoration(
                  labelText: 'Pilih Kendaraan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                items: armadaList.map((a) => DropdownMenuItem(
                  value: a,
                  child: Text('${a.platNomor} — ${a.jenis ?? a.kodeUnit ?? ""}'),
                )).toList(),
                onChanged: _onArmadaChanged,
              ),

              if (_selectedArmada != null) ...[
                const SizedBox(height: 20),

                // Info ODO terkini
                if (_selectedArmada!.odoTerkini != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                          color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ODO Terakhir Tercatat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fmtKm(_selectedArmada!.odoTerkini),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                          color: AppTheme.warningColor, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Belum ada ODO tercatat untuk unit ini hari ini.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Input ODO Sekarang
                TextFormField(
                  controller: _odoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _selectedArmada!.isAlatBerat
                        ? 'Jam Operasional Sekarang (HM)'
                        : 'ODO Sekarang (KM)',
                    suffixText: _selectedArmada!.isAlatBerat ? 'HM' : 'KM',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(_selectedArmada!.isAlatBerat
                        ? Icons.timer_outlined
                        : Icons.speed_outlined),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Menyimpan...' : 'Simpan ODO'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
