import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import 'armada_providers.dart';
import 'models/armada.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// KM Harian — input kilometer sekali per hari.
/// Form tunggal: pilih kendaraan, lihat KM terakhir, update KM sekarang.
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
      // Prefill dengan KM terkini jika ada
      if (armada?.odoTerkini != null) {
        _odoController.text = armada!.odoTerkini!.toStringAsFixed(0);
      } else {
        _odoController.clear();
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedArmada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kendaraan terlebih dahulu')),
      );
      return;
    }
    if (_odoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedArmada!.isAlatBerat
                ? 'Jam Kerja Unit harus diisi'
                : 'KM harus diisi',
          ),
        ),
      );
      return;
    }

    final odoValue = double.tryParse(_odoController.text.trim());
    if (odoValue == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Format angka tidak valid')));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final delivered = await ref
          .read(armadaRepositoryProvider)
          .submitOdoAwalProyek(
            armadaId: _selectedArmada!.id,
            titikId: _selectedArmada!.titikId ?? '',
            odoAwal: odoValue,
          );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      AnalyticsService.odoSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? (_selectedArmada!.isAlatBerat
                      ? 'Jam Kerja Unit berhasil diperbarui'
                      : 'KM terkini berhasil diperbarui')
                : 'Menunggu Terkirim — tersimpan di HP, dikirim otomatis saat online. Gunakan tombol ☁️ di atas untuk sinkron manual.',
          ),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/armada/unit-saya');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan.\nPeriksa koneksi lalu coba lagi.'),
        ),
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
        title: const Text('KM Harian'),
        actions: [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => AppEmptyState(
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
              icon: Icons.local_shipping_outlined,
              title: 'Tidak ada armada yang ditugaskan',
              subtitle:
                  'Hubungi admin untuk mendapatkan penugasan unit kendaraan.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<ArmadaSaya>(
                initialValue: _selectedArmada,
                decoration: const InputDecoration(
                  labelText: 'Pilih Kendaraan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                  helperText: 'Pilih unit yang akan Anda operasikan hari ini',
                ),
                items: armadaList
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(
                          '${a.platNomor} — ${a.jenis ?? a.kodeUnit ?? ""}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onArmadaChanged,
              ),

              if (_selectedArmada != null) ...[
                const SizedBox(height: 20),

                if (_selectedArmada!.isAlatBerat
                    ? _selectedArmada!.jamOperasionalTerkini != null
                    : _selectedArmada!.odoTerkini != null)
                  Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.colors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.colors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedArmada!.isAlatBerat
                                    ? 'Jam Kerja Unit Terakhir Tercatat'
                                    : 'KM Terakhir Tercatat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textTertiary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                _selectedArmada!.isAlatBerat
                                    ? '${_selectedArmada!.jamOperasionalTerkini} jam'
                                    : fmtKm(_selectedArmada!.odoTerkini),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.primary,
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
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colors.warning.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.colors.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: context.colors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedArmada!.isAlatBerat
                                ? 'Belum ada Jam Kerja Unit tercatat untuk unit ini hari ini.'
                                : 'Belum ada KM tercatat untuk unit ini hari ini.',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: _odoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _selectedArmada!.isAlatBerat
                        ? 'Jam Kerja Unit Sekarang (HM)'
                        : 'KM Sekarang (Odometer)',
                    suffixText: _selectedArmada!.isAlatBerat ? 'HM' : 'KM',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      _selectedArmada!.isAlatBerat
                          ? Icons.timer_outlined
                          : Icons.speed_outlined,
                    ),
                    helperText: _selectedArmada!.isAlatBerat
                        ? 'Total jam mesin menyala dari Hour Meter'
                        : 'Angka pada odometer (penghitung km) kendaraan',
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: BouncingButton(
                    onPressed: _isLoading ? null : _submit,
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
                      label: Text(
                        _isLoading
                            ? 'Menyimpan...'
                            : _selectedArmada!.isAlatBerat
                            ? 'Simpan Jam Kerja Unit'
                            : 'Simpan KM',
                      ),
                    ),
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
