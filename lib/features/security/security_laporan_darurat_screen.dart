import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/submit_spinner.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'security_repository.dart';

/// Form Laporan Darurat Security (Section 27, TD-F4).
class SecurityLaporanDaruratScreen extends ConsumerStatefulWidget {
  const SecurityLaporanDaruratScreen({super.key});

  @override
  ConsumerState<SecurityLaporanDaruratScreen> createState() =>
      _SecurityLaporanDaruratScreenState();
}

class _SecurityLaporanDaruratScreenState
    extends ConsumerState<SecurityLaporanDaruratScreen> {
  final _formKey = GlobalKey<FormState>();

  String _kategori = 'Keamanan & Penyusup';
  String _tingkat = 'darurat';

  final _judulCtrl = TextEditingController();
  final _lokasiCtrl = TextEditingController();
  final _deskripsiCtrl = TextEditingController();

  final List<String> _fotoPaths = [];
  bool _isSubmitting = false;

  final List<String> _kategoriOptions = const [
    'Keamanan & Penyusup',
    'Kebakaran & Asap',
    'Kecelakaan Kerja',
    'Kerusakan Fasilitas Kritis',
    'Medis & Kesehatan',
    'Bencana Alam & Cuaca',
    'Lainnya',
  ];

  @override
  void dispose() {
    _judulCtrl.dispose();
    _lokasiCtrl.dispose();
    _deskripsiCtrl.dispose();
    super.dispose();
  }

  Future<void> _addFoto() async {
    final captured = await takeWatermarkedPhoto(ref);
    if (captured != null && mounted) {
      setState(() => _fotoPaths.add(captured.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final repo = ref.read(securityRepositoryProvider);
      await repo.submitLaporanDarurat(
        kategori: _kategori,
        judul: _judulCtrl.text.trim(),
        deskripsi: _deskripsiCtrl.text.trim(),
        lokasiRuangan: _lokasiCtrl.text.trim(),
        tingkat: _tingkat,
        fotoPaths: _fotoPaths,
      );

      AnalyticsService.log('security_laporan_darurat_submit', {
        'kategori': _kategori,
        'tingkat': _tingkat,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Laporan darurat terkirim & diteruskan ke Owner serta Ketua Divisi Armada.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal mengirim laporan. Coba lagi.'),
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
      appBar: AppBar(
        title: const Text('Laporan Darurat'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner Peringatan
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Laporan ini akan segera diteruskan ke Owner & Ketua Divisi Armada.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tingkat Kedaruratan
            const Text('Tingkat Kedaruratan', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'siaga',
                  label: Text('Siaga'),
                  icon: Icon(Icons.info_outline, color: Colors.amber),
                ),
                ButtonSegment(
                  value: 'darurat',
                  label: Text('Darurat'),
                  icon: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                ),
                ButtonSegment(
                  value: 'kritis',
                  label: Text('Kritis'),
                  icon: Icon(Icons.crisis_alert_rounded, color: Colors.red),
                ),
              ],
              selected: {_tingkat},
              onSelectionChanged: (set) => setState(() => _tingkat = set.first),
            ),
            const SizedBox(height: 16),

            // Kategori
            DropdownButtonFormField<String>(
              initialValue: _kategori,
              decoration: const InputDecoration(
                labelText: 'Kategori Kejadian',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _kategoriOptions
                  .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _kategori = v);
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _judulCtrl,
              decoration: const InputDecoration(
                labelText: 'Judul Singkat Kejadian',
                hintText: 'Contoh: Indikasi Asap di Gudang B',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _lokasiCtrl,
              decoration: const InputDecoration(
                labelText: 'Lokasi / Ruangan',
                hintText: 'Contoh: Pos Timur / Gudang Solar / Blok CBP 2',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Lokasi wajib diisi' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _deskripsiCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi Detail Kejadian',
                hintText: 'Jelaskan situasi yang terjadi, korban (jika ada), dan tindakan pertama...',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Deskripsi kejadian wajib diisi' : null,
            ),
            const SizedBox(height: 16),

            // Foto Bukti
            Text(
              'Foto Bukti (Opsional - Multi Foto)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            if (_fotoPaths.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fotoPaths.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) => Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_fotoPaths[idx]),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      IconButton(
                        icon: const CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                        onPressed: () => setState(() => _fotoPaths.removeAt(idx)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            OutlinedButton.icon(
              onPressed: _addFoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Tambah Foto Bukti'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: BouncingButton(
                onPressed: _isSubmitting ? () {} : _submit,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                  ),
                  icon: _isSubmitting
                      ? const SubmitSpinner(size: 18)
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Mengirim...' : 'Kirim Laporan Darurat Sekarang',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
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
