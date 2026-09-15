import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'armada_providers.dart';
import 'models/armada.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../core/analytics_service.dart';
import '../../core/api_client.dart';

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
    _ChecklistItem(label: 'KM (Odometer)', status: _ItemStatus.baik),
    _ChecklistItem(label: 'Kelengkapan Dokumen', status: _ItemStatus.baik),
  ];
  final Map<String, String> _photos = {};
  bool _isSubmitting = false;
  ArmadaSaya? _selectedArmada;
  bool _vehicleSelected = false;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(String itemLabel) async {
    HapticFeedback.lightImpact();
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null) return;
    setState(() {
      _photos[itemLabel] = photo.path;
    });
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);
    try {
      // TODO: Kirim ke backend POST /armada/checklist-major
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist Serah Terima tersimpan')),
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
          content: Text(
            'Gagal menyimpan checklist.\nPeriksa koneksi lalu coba lagi.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step 1: Pilih kendaraan
    if (!_vehicleSelected) {
      return _VehicleSelectionStep(
        onSelected: (armada) {
          setState(() {
            _selectedArmada = armada;
            _vehicleSelected = true;
          });
        },
      );
    }

    // Step 2: Checklist form
    final hasIssue = _items.any((i) => i.status != _ItemStatus.baik);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Checklist Serah Terima — ${_selectedArmada?.platNomor ?? ''}',
        ),
        actions: [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          // Step indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: context.colors.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: context.colors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Langkah 2 dari 2 — Isi Checklist',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
                Spacer(),
                Text(
                  '10 item',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Warning banner
          if (hasIssue)
            Container(
              padding: EdgeInsets.all(12),
              color: context.colors.warning.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: context.colors.warning,
                    size: 20,
                  ),
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
                  index: index + 1,
                  photoPath: _photos[item.label],
                  onStatusChanged: (status) {
                    setState(() {
                      _items[index] = item.copyWith(status: status);
                    });
                    AnalyticsService.checklistItemToggle(
                      item.label,
                      status == _ItemStatus.baik,
                    );
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
              height: 48,
              child: BouncingButton(
                onPressed: _isSubmitting ? null : _submit,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Menyimpan...'),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_outlined, size: 20),
                            SizedBox(width: 8),
                            Text('Simpan Checklist Serah Terima'),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 1: Pilih kendaraan sebelum checklist.
class _VehicleSelectionStep extends ConsumerWidget {
  const _VehicleSelectionStep({required this.onSelected});

  final ValueChanged<ArmadaSaya> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final armadaAsync = ref.watch(armadaSayaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Serah Terima'),
        actions: [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: context.colors.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(
                  Icons.directions_car,
                  size: 16,
                  color: context.colors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Langkah 1 dari 2 — Pilih Kendaraan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: armadaAsync.when(
              loading: () => Center(child: CircularProgressIndicator()),
              error: (_, __) => AppEmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Gagal memuat data armada',
                subtitle:
                    'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
                actionLabel: 'Coba lagi',
                onAction: () => ref.invalidate(armadaSayaProvider),
              ),
              data: (armadaList) {
                if (armadaList.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Tidak ada armada',
                    subtitle: 'Anda belum memiliki armada yang ditugaskan.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      color: context.colors.primary.withValues(alpha: 0.05),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_car,
                            color: context.colors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pilih kendaraan untuk checklist serah terima',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: armadaList.length,
                        itemBuilder: (context, index) {
                          final armada = armadaList[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: context.colors.primary
                                    .withValues(alpha: 0.1),
                                child: Icon(
                                  Icons.local_shipping,
                                  color: context.colors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                armada.platNomor,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${armada.jenis ?? 'N/A'}${armada.titikNama != null ? ' • ${armada.titikNama}' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textTertiary,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => onSelected(armada),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _ItemStatus { baik, rusakRingan, rusakBerat }

class _ChecklistItem {
  const _ChecklistItem({required this.label, required this.status});

  final String label;
  final _ItemStatus status;

  _ChecklistItem copyWith({_ItemStatus? status}) {
    return _ChecklistItem(label: label, status: status ?? this.status);
  }
}

class _MajorChecklistTile extends StatelessWidget {
  const _MajorChecklistTile({
    required this.item,
    required this.index,
    this.photoPath,
    required this.onStatusChanged,
    required this.onTakePhoto,
  });

  final _ChecklistItem item;
  final int index;
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
    final displayNum = index.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Index badge
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayNum,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                    photoPath != null
                        ? Icons.photo_camera
                        : Icons.camera_alt_outlined,
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
                        backgroundColor: isSelected
                            ? sColor.withValues(alpha: 0.1)
                            : null,
                        side: BorderSide(
                          color: isSelected ? sColor : Colors.grey.shade300,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? sColor
                              : context.colors.textTertiary,
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
                  errorBuilder: (context, error, stack) => ColoredBox(
                    color: context.colors.surfaceVariant,
                    child: SizedBox(
                      height: 80,
                      width: 80,
                      child: Icon(Icons.image, color: context.colors.textMuted),
                    ),
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
