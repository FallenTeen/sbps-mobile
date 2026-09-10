import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';

/// Checklist Major — Serah Terima Sewa (Section 21.10):
/// Isi kondisi kendaraan detail + foto untuk serah terima.
/// Cetak PDF tetap di web; mobile hanya untuk input kondisi + foto.
class ChecklistMajorScreen extends ConsumerStatefulWidget {
  const ChecklistMajorScreen({super.key});

  @override
  ConsumerState<ChecklistMajorScreen> createState() =>
      _ChecklistMajorScreenState();
}

class _ChecklistMajorScreenState extends ConsumerState<ChecklistMajorScreen> {
  final _catatanCtrl = TextEditingController();
  final List<_ChecklistItem> _items = [
    _ChecklistItem(label: 'Body / Karoseri', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Mesin', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Transmisi', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Rem', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Ban', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Kaca / Spion', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Lampu', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Interior', status: _ItemStatus.baik),
    _ChecklistItem(label: 'ODOMETER', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Kelengkapan Dokumen', status: _ItemStatus.baik),
  ];
  final Map<String, String> _photos = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(String itemLabel) async {
    final photo = await ref.takeWatermarkedPhoto();
    if (photo == null) return;
    setState(() {
      _photos[itemLabel] = photo.path;
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      // TODO: Kirim ke backend POST /armada/checklist-major
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist Major tersimpan')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan checklist')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasIssue = _items.any((i) => i.status != _ItemStatus.baik);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Major'),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          // Warning banner
          if (hasIssue)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warningColor, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Ada item yang tidak dalam kondisi baik. Pastikan semua item terdokumentasi.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Checklist items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return _MajorChecklistTile(
                  item: item,
                  photoPath: _photos[item.label],
                  onStatusChanged: (status) {
                    setState(() {
                      _items[index] = item.copyWith(status: status);
                    });
                  },
                  onTakePhoto: () => _takePhoto(item.label),
                );
              },
            ),
          ),

          // Catatan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _catatanCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan Tambahan',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Submit
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Simpan Checklist Major'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ItemStatus { baik, rusakRingan, rusakBerat }

class _ChecklistItem {
  const _ChecklistItem({
    required this.label,
    required this.status,
  });

  final String label;
  final _ItemStatus status;

  _ChecklistItem copyWith({_ItemStatus? status}) {
    return _ChecklistItem(
      label: label,
      status: status ?? this.status,
    );
  }
}

class _MajorChecklistTile extends StatelessWidget {
  const _MajorChecklistTile({
    required this.item,
    this.photoPath,
    required this.onStatusChanged,
    required this.onTakePhoto,
  });

  final _ChecklistItem item;
  final String? photoPath;
  final ValueChanged<_ItemStatus> onStatusChanged;
  final VoidCallback onTakePhoto;

  Color _statusColor(_ItemStatus status) {
    return switch (status) {
      _ItemStatus.baik => Colors.green,
      _ItemStatus.rusakRingan => Colors.orange,
      _ItemStatus.rusakBerat => Colors.red,
    };
  }

  String _statusLabel(_ItemStatus status) {
    return switch (status) {
      _ItemStatus.baik => 'Baik',
      _ItemStatus.rusakRingan => 'Rusak Ringan',
      _ItemStatus.rusakBerat => 'Rusak Berat',
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(item.status),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    photoPath != null ? Icons.photo_camera : Icons.camera_alt_outlined,
                    color: photoPath != null ? Colors.green : null,
                  ),
                  onPressed: onTakePhoto,
                  tooltip: 'Ambil foto',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Status buttons
            Row(
              children: _ItemStatus.values.map((status) {
                final isSelected = item.status == status;
                final sColor = _statusColor(status);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: OutlinedButton(
                      onPressed: () => onStatusChanged(status),
                      style: OutlinedButton.styleFrom(
                        backgroundColor:
                            isSelected ? sColor.withValues(alpha: 0.1) : null,
                        side: BorderSide(
                          color: isSelected ? sColor : Colors.grey.shade300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? sColor : AppTheme.textTertiary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            // Photo preview
            if (photoPath != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  photoPath!,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    width: 80,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
