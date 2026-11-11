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
import 'models/security_models.dart';
import 'security_repository.dart';

/// Layar Checklist Pemantauan Kantor (Section 27, TD-F3).
class SecurityChecklistScreen extends ConsumerStatefulWidget {
  const SecurityChecklistScreen({super.key});

  @override
  ConsumerState<SecurityChecklistScreen> createState() =>
      _SecurityChecklistScreenState();
}

class _SecurityChecklistScreenState
    extends ConsumerState<SecurityChecklistScreen> {
  String _periode = 'harian_siang';
  late String _jamPantau;
  final _catatanUmumCtrl = TextEditingController();
  bool _isSubmitting = false;

  late List<ChecklistKantorItem> _items;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _jamPantau = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _periode = (now.hour >= 18 || now.hour < 6) ? 'malam' : 'harian_siang';

    _items = [
      ChecklistKantorItem(id: 'c1', label: 'Pintu utama & pintu akses belakang terkunci rapat'),
      ChecklistKantorItem(id: 'c2', label: 'Jendela ruangan kantor & ventilasi tertutup aman'),
      ChecklistKantorItem(id: 'c3', label: 'Lampu penerangan perimeter luar & lorong menyala'),
      ChecklistKantorItem(id: 'c4', label: 'CCTV & indikator DVR beroperasi normal'),
      ChecklistKantorItem(id: 'c5', label: 'APAR (Alat Pemadam Api Ringan) dalam posisi aman & siap pakai'),
      ChecklistKantorItem(id: 'c6', label: 'Area parkir armada & kendaraan karyawan terkontrol aman'),
      ChecklistKantorItem(id: 'c7', label: 'Gerbang utama & pos jaga terkunci/terpantau'),
    ];
  }

  @override
  void dispose() {
    _catatanUmumCtrl.dispose();
    super.dispose();
  }

  Future<void> _takeFotoItem(ChecklistKantorItem item) async {
    final captured = await takeWatermarkedPhoto(ref);
    if (captured != null && mounted) {
      setState(() => item.fotoPath = captured.path);
    }
  }

  Future<void> _submit() async {
    final checkedCount = _items.where((i) => i.isChecked).length;
    if (checkedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap centang minimal 1 item checklist')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(securityRepositoryProvider);
      final photoPaths = _items.map((i) => i.fotoPath).whereType<String>().toList();

      await repo.submitChecklistKantor(
        periode: _periode,
        jamPantau: _jamPantau,
        items: _items,
        catatan: _catatanUmumCtrl.text.trim().isEmpty ? null : _catatanUmumCtrl.text.trim(),
        fotoPaths: photoPaths,
      );

      AnalyticsService.log('security_checklist_submit', {
        'periode': _periode,
        'checked_count': checkedCount,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Checklist pemantauan kantor berhasil disimpan.'),
          backgroundColor: context.colors.success,
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal menyimpan checklist. Coba lagi.'),
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
        title: const Text('Checklist Pemantauan Kantor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Periode & Jam Pantau
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Periode Pemantauan', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'harian_siang', label: Text('Siang')),
                      ButtonSegment(value: 'malam', label: Text('Malam')),
                      ButtonSegment(value: 'custom', label: Text('Khusus')),
                    ],
                    selected: {_periode},
                    onSelectionChanged: (set) => setState(() => _periode = set.first),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Jam Pantau: $_jamPantau WIB', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Item Pemeriksaan Fasilitas & Keamanan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          for (final item in _items) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: item.isChecked ? context.colors.success.withValues(alpha: 0.4) : context.colors.border,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: item.isChecked,
                      onChanged: (v) => setState(() => item.isChecked = v ?? false),
                      title: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    if (item.isChecked) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 48, right: 12, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: item.catatan,
                                onChanged: (v) => item.catatan = v,
                                decoration: const InputDecoration(
                                  hintText: 'Catatan kondisi (opsional)',
                                  isDense: true,
                                  border: UnderlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                item.fotoPath != null ? Icons.photo_camera : Icons.add_a_photo_outlined,
                                color: item.fotoPath != null ? context.colors.success : null,
                                size: 20,
                              ),
                              tooltip: 'Lampirkan Foto',
                              onPressed: () => _takeFotoItem(item),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          const SizedBox(height: 14),
          TextFormField(
            controller: _catatanUmumCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan Umum Pemantauan (opsional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 48,
            child: BouncingButton(
              onPressed: _isSubmitting ? () {} : _submit,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SubmitSpinner(size: 18)
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Mengirim...' : 'Kirim Checklist Pemantauan'),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
