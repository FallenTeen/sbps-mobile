import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/submit_spinner.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../armada/models/armada.dart';
import 'logistik_repository.dart';

/// Form Verifikasi Ritase & Timbang oleh Logistik (Section 27, TD-E3).
class LogistikVerifikasiScreen extends ConsumerStatefulWidget {
  const LogistikVerifikasiScreen({
    super.key,
    required this.ritaseId,
    this.ritase,
  });

  final String ritaseId;
  final RitaseItem? ritase;

  @override
  ConsumerState<LogistikVerifikasiScreen> createState() =>
      _LogistikVerifikasiScreenState();
}

class _LogistikVerifikasiScreenState
    extends ConsumerState<LogistikVerifikasiScreen> {
  final _formKey = GlobalKey<FormState>();

  final _beratKosongCtrl = TextEditingController();
  final _beratIsiCtrl = TextEditingController();
  final _jumlahVerifikasiCtrl = TextEditingController();
  final _nomorTiketCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  bool _isTimbangUlang = false;
  String? _fotoTiketPath;
  bool _isSubmitting = false;

  bool _checkJenisSesuai = true;
  bool _checkJumlahSesuai = true;
  bool _checkPlatSesuai = true;
  bool _checkTerpalAman = true;

  @override
  void initState() {
    super.initState();
    final r = widget.ritase;
    final defaultTara = r?.taraMasterKg ?? r?.beratKosongKg ?? 8500.0;
    _beratKosongCtrl.text = defaultTara.toStringAsFixed(0);

    if (r?.beratIsiKg != null) {
      _beratIsiCtrl.text = r!.beratIsiKg!.toStringAsFixed(0);
    }
    if (r?.jumlahVerifikasiLogistik != null) {
      _jumlahVerifikasiCtrl.text = r!.jumlahVerifikasiLogistik!.toString();
    } else if (r?.jumlahDriver != null) {
      _jumlahVerifikasiCtrl.text = r!.jumlahDriver!.toString();
    }

    _beratKosongCtrl.addListener(_recalculateNetto);
    _beratIsiCtrl.addListener(_recalculateNetto);
  }

  @override
  void dispose() {
    _beratKosongCtrl.dispose();
    _beratIsiCtrl.dispose();
    _jumlahVerifikasiCtrl.dispose();
    _nomorTiketCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  void _recalculateNetto() {
    final kosong = double.tryParse(_beratKosongCtrl.text.replaceAll(',', '.')) ?? 0;
    final isi = double.tryParse(_beratIsiCtrl.text.replaceAll(',', '.')) ?? 0;
    if (isi > kosong && kosong > 0) {
      final nettoKg = isi - kosong;
      final nettoTon = nettoKg / 1000.0;
      setState(() {
        _jumlahVerifikasiCtrl.text = nettoTon.toStringAsFixed(2);
      });
    } else {
      setState(() {});
    }
  }

  double get _currentNettoKg {
    final kosong = double.tryParse(_beratKosongCtrl.text.replaceAll(',', '.')) ?? 0;
    final isi = double.tryParse(_beratIsiCtrl.text.replaceAll(',', '.')) ?? 0;
    return (isi - kosong).clamp(0, double.infinity);
  }

  double get _currentNettoTon => _currentNettoKg / 1000.0;

  Future<void> _takeFotoTiket() async {
    final captured = await takeWatermarkedPhoto(ref);
    if (captured != null && mounted) {
      setState(() => _fotoTiketPath = captured.path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final kosong = double.tryParse(_beratKosongCtrl.text.replaceAll(',', '.'));
    final isi = double.tryParse(_beratIsiCtrl.text.replaceAll(',', '.'));
    final verifTon = double.tryParse(_jumlahVerifikasiCtrl.text.replaceAll(',', '.'));

    if (kosong == null || kosong <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berat kosong / tara harus angka positif')),
      );
      return;
    }
    if (isi == null || isi <= kosong) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berat isi (bruto) harus lebih besar dari berat kosong')),
      );
      return;
    }
    if (verifTon == null || verifTon <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah verifikasi resmi harus angka positif')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(logistikRepositoryProvider);
      await repo.submitVerifikasiRitase(
        ritaseId: widget.ritaseId,
        jumlahVerifikasi: verifTon,
        beratKosongKg: kosong,
        beratIsiKg: isi,
        beratNettoKg: isi - kosong,
        isTimbangUlang: _isTimbangUlang,
        checklist: {
          'jenis_sesuai': _checkJenisSesuai,
          'jumlah_sesuai': _checkJumlahSesuai,
          'plat_sesuai': _checkPlatSesuai,
          'terpal_aman': _checkTerpalAman,
        },
        nomorTiket: _nomorTiketCtrl.text.trim().isEmpty ? null : _nomorTiketCtrl.text.trim(),
        fotoTiketPath: _fotoTiketPath,
        catatan: _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
      );

      AnalyticsService.log('logistik_verifikasi_ritase_submit', {
        'ritase_id': widget.ritaseId,
        'jumlah_verifikasi': verifTon,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verifikasi muatan & timbang berhasil disimpan.'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan verifikasi: $e'),
          backgroundColor: context.colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ritase;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Muatan & Timbang'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Unit & Ritase Card
            Card(
              elevation: 0,
              color: context.colors.surfaceVariant.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, color: context.colors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r?.armadaPlat ?? 'Unit Kendaraan',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (r?.wajibJembatanTimbang == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Wajib Timbang',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.purple),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Sopir: ${r?.driverNama ?? 'Driver'}'),
                    if (r?.ruteAsal != null || r?.ruteTujuan != null)
                      Text('Rute: ${r?.ruteAsal ?? '-'} → ${r?.ruteTujuan ?? '-'}'),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Material: ${r?.material ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          'Versi Sopir: ${r?.jumlahDriver != null ? "${r!.jumlahDriver} ${r.satuanMuatan ?? 'ton'}" : "${r?.jumlahRit ?? 1} rit"}',
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bagian 1: Tara / Berat Kosong
            Text('1. Tara (Berat Kosong)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            const SizedBox(height: 6),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Timbang Ulang Kosong', style: TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  _isTimbangUlang ? 'Memasukkan tara hasil timbang baru' : 'Menggunakan tara master unit (${_beratKosongCtrl.text} kg)',
                                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isTimbangUlang,
                            onChanged: (v) {
                              setState(() => _isTimbangUlang = v);
                              if (!v) {
                                final defaultTara = r?.taraMasterKg ?? 8500.0;
                                _beratKosongCtrl.text = defaultTara.toStringAsFixed(0);
                              }
                            },
                          ),
                        ],
                      ),
                      if (_isTimbangUlang) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _beratKosongCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Berat Kosong Baru (kg)',
                            hintText: 'Contoh: 8450',
                            border: OutlineInputBorder(),
                            suffixText: 'kg',
                            isDense: true,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                            final val = double.tryParse(v.replaceAll(',', '.'));
                            if (val == null || val <= 0) return 'Harus angka positif';
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bagian 2: Berat Isi (Bruto)
              Text('2. Berat Isi (Bruto)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _beratIsiCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Berat Isi / Bruto (kg)',
                  hintText: 'Contoh: 24500',
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Berat isi wajib diisi';
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Harus angka positif';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Hasil Netto Otomatis
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hasil Netto (Isi − Kosong):', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${_currentNettoTon.toStringAsFixed(2)} ton',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Metrik kg: ${_currentNettoKg.toStringAsFixed(0)} kg', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                        Text('Estimasi volume: ~${(_currentNettoTon / 1.4).toStringAsFixed(2)} m³', style: TextStyle(fontSize: 12, color: context.colors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bagian 3: Checklist Muatan Logistik
              Text('3. Checklist Muatan Logistik', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 6),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _checkJenisSesuai,
                      onChanged: (v) => setState(() => _checkJenisSesuai = v ?? false),
                      title: const Text('Kesesuaian jenis / material muatan', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      value: _checkJumlahSesuai,
                      onChanged: (v) => setState(() => _checkJumlahSesuai = v ?? false),
                      title: const Text('Kesesuaian fisik jumlah muatan', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      value: _checkPlatSesuai,
                      onChanged: (v) => setState(() => _checkPlatSesuai = v ?? false),
                      title: const Text('Kendaraan & nomor plat sesuai', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const Divider(height: 1),
                    CheckboxListTile(
                      value: _checkTerpalAman,
                      onChanged: (v) => setState(() => _checkTerpalAman = v ?? false),
                      title: const Text('Kondisi penutup muatan / terpal aman & rapi', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bagian 4: Jumlah Verifikasi Resmi
              Text('4. Jumlah Verifikasi Resmi (Ton)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                'Hanya Logistik yang dapat mengisi angka verifikasi resmi ini.',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _jumlahVerifikasiCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Jumlah Muatan Resmi (ton)',
                  border: OutlineInputBorder(),
                  suffixText: 'ton',
                  helperText: 'Otomatis terisi dari hasil netto timbang, dapat disesuaikan bila ada toleransi',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Jumlah verifikasi wajib diisi';
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Harus angka positif';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bagian 5: Tiket Timbang & Catatan Opsional
              Text('5. Dokumen Timbangan & Catatan (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nomorTiketCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nomor Tiket Timbang (opsional)',
                  hintText: 'Contoh: TMB-202611-0042',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              if (_fotoTiketPath != null) ...[
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(_fotoTiketPath!),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                      onPressed: () => setState(() => _fotoTiketPath = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ] else
                OutlinedButton.icon(
                  onPressed: _takeFotoTiket,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Foto Tiket Timbang (Opsional)'),
                ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _catatanCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan Logistik (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Submit
              SizedBox(
                height: 48,
                child: BouncingButton(
                  onPressed: _isSubmitting ? () {} : _submit,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SubmitSpinner(size: 18)
                        : const Icon(Icons.verified_outlined),
                    label: Text(_isSubmitting ? 'Menyimpan...' : 'Simpan & Verifikasi Ritase'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
      ),
    );
  }
}
