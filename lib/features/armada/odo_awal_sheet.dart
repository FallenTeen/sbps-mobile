import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import 'armada_providers.dart';
import 'models/armada.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/bouncing_button.dart';

/// KM Harian Sheet (Fase 2) - Converted from full screen to sheet
/// Form sederhana: pilih kendaraan, lihat KM terakhir, update KM sekarang.
/// ≤3 fields → use sheet pattern instead of route.
class OdoAwalSheet extends ConsumerStatefulWidget {
  const OdoAwalSheet({super.key});

  @override
  ConsumerState<OdoAwalSheet> createState() => _OdoAwalSheetState();
}

class _OdoAwalSheetState extends ConsumerState<OdoAwalSheet> {
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
      ).showSnackBar(SnackBar(content: Text('Format angka tidak valid')));
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
                : kCopyQueued,
          ),
        ),
      );
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

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                margin: EdgeInsets.symmetric(vertical: 12),
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
                    Expanded(
                      child: Text(
                        _selectedArmada?.isAlatBerat == true
                            ? 'Input Jam Kerja Unit'
                            : 'Input KM Harian',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
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
              Divider(height: 1),
              // Content
              Expanded(
                child: armadaAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48),
                        const SizedBox(height: 12),
                        const Text('Gagal memuat data armada'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(armadaSayaProvider),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                  data: (armadaList) {
                    if (armadaList.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 48),
                            SizedBox(height: 12),
                            Text('Tidak ada armada yang ditugaskan'),
                          ],
                        ),
                      );
                    }

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        DropdownButtonFormField<ArmadaSaya>(
                          initialValue: _selectedArmada,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Kendaraan',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                            helperText:
                                'Pilih unit yang akan Anda operasikan hari ini',
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
                                color: context.colors.primary.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.colors.primary.withValues(
                                    alpha: 0.2,
                                  ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              : fmtKm(
                                                  _selectedArmada!.odoTerkini,
                                                ),
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
                                color: context.colors.warning.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.colors.warning.withValues(
                                    alpha: 0.2,
                                  ),
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
                              suffixText: _selectedArmada!.isAlatBerat
                                  ? 'HM'
                                  : 'KM',
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
              ),
            ],
          ),
        );
      },
    );
  }
}
