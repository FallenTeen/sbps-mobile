import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_service.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/form_section.dart';
import '../../shared/widgets/sticky_action_bar.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'models/security_models.dart';
import 'security_repository.dart';

/// Form Input Buku Tamu Baru (Section 27).
class SecurityBukuTamuFormScreen extends ConsumerStatefulWidget {
  const SecurityBukuTamuFormScreen({super.key});

  @override
  ConsumerState<SecurityBukuTamuFormScreen> createState() =>
      _SecurityBukuTamuFormScreenState();
}

class _SecurityBukuTamuFormScreenState
    extends ConsumerState<SecurityBukuTamuFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _namaCtrl = TextEditingController();
  final _jumlahOrangCtrl = TextEditingController(text: '1');
  final _asalCtrl = TextEditingController();
  final _nomorTeleponCtrl = TextEditingController();
  final _platNomorCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  KendaraanTamu _kendaraan = KendaraanTamu.motor;
  String? _fotoPath;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _namaCtrl.dispose();
    _jumlahOrangCtrl.dispose();
    _asalCtrl.dispose();
    _nomorTeleponCtrl.dispose();
    _platNomorCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _takeFoto() async {
    final captured = await takeWatermarkedPhoto(ref);
    if (captured != null && mounted) {
      setState(() => _fotoPath = captured.path);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final jml = int.tryParse(_jumlahOrangCtrl.text.trim()) ?? 1;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(securityRepositoryProvider);
      await repo.submitBukuTamu(
        nama: _namaCtrl.text.trim(),
        jumlahOrang: jml,
        asal: _asalCtrl.text.trim(),
        nomorTelepon: _nomorTeleponCtrl.text.trim().isEmpty
            ? null
            : _nomorTeleponCtrl.text.trim(),
        kendaraan: _kendaraan,
        platNomor: _platNomorCtrl.text.trim().isEmpty
            ? null
            : _platNomorCtrl.text.trim(),
        fotoPath: _fotoPath,
        catatan: _catatanCtrl.text.trim().isEmpty
            ? null
            : _catatanCtrl.text.trim(),
      );

      AnalyticsService.log('security_buku_tamu_submit', {
        'nama': _namaCtrl.text.trim(),
        'kendaraan': _kendaraan.name,
      });

      if (!mounted) return;
      FeedbackService.success(context, 'Catatan tamu berhasil disimpan.');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              e,
              fallback: 'Gagal menyimpan tamu. Coba lagi.',
            ),
          ),
          backgroundColor: context.colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Tamu Baru')),
      body: Form(
        key: _formKey,
        child: FocusTraversalGroup(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    FormSection(
                      title: 'Identitas Tamu',
                      children: [
                        TextFormField(
                          controller: _namaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap Tamu',
                            hintText: 'Contoh: Budi Santoso',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nama wajib diisi'
                              : null,
                        ),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _asalCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Asal / Instansi / PT',
                                  hintText: 'Contoh: PT Semen Indonesia',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.business_outlined),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Asal instansi wajib diisi'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _jumlahOrangCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Jumlah Orang',
                                  border: OutlineInputBorder(),
                                  suffixText: 'org',
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n <= 0) return 'Min 1';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        TextFormField(
                          controller: _nomorTeleponCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Telepon / WhatsApp (opsional)',
                            hintText: 'Contoh: 081234567890',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      title: 'Kendaraan',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<KendaraanTamu>(
                                initialValue: _kendaraan,
                                decoration: const InputDecoration(
                                  labelText: 'Kendaraan',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: KendaraanTamu.values
                                    .map(
                                      (k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _kendaraan = v);
                                },
                              ),
                            ),
                            if (_kendaraan != KendaraanTamu.tanpaKendaraan) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _platNomorCtrl,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Plat Nomor (opsional)',
                                    hintText: 'Contoh: B 1234 CD',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    FormSection(
                      title: 'Foto & Catatan',
                      children: [
                        Text(
                          'Foto Tamu / Kendaraan (Opsional - 1 Foto)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        if (_fotoPath != null)
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_fotoPath!),
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              IconButton(
                                icon: const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () =>
                                    setState(() => _fotoPath = null),
                              ),
                            ],
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: _takeFoto,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Ambil Foto Tamu / Kendaraan'),
                          ),
                        TextFormField(
                          controller: _catatanCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Keperluan / Catatan (opsional)',
                            hintText:
                                'Contoh: Bertemu Bpk. Andi bagian Keuangan',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              StickyActionBar(
                primaryLabel: _isSubmitting
                    ? 'Menyimpan...'
                    : 'Simpan Buku Tamu',
                onPrimary: _isSubmitting ? () {} : _submit,
                showPrimaryLoading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
