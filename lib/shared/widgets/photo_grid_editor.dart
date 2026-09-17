import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'confirmation_dialog.dart';
import 'photo_viewer_dialog.dart';
import 'watermarked_camera_capture.dart';

/// Grid foto editor — pola "Dokumentasi" (PHASE 06).
///
/// Satu komponen untuk menambah, preview, menghapus, dan mengambil ulang
/// foto form. Dipakai Formulir Lapangan & Dokumentasi Produksi sehingga
/// perilaku preview/delete/retake konsisten di seluruh app.
///
/// Foto selalu diambil lewat [takeWatermarkedPhoto] (watermark + kompresi);
/// perubahan dilaporkan ke pemilik via [onPathsChanged] dengan list baru.
class PhotoGridEditor extends ConsumerWidget {
  const PhotoGridEditor({
    super.key,
    required this.paths,
    required this.onPathsChanged,
    this.maxCount = 5,
    this.enabled = true,
    this.heroTagPrefix = 'photo_editor',
  });

  final List<String> paths;
  final ValueChanged<List<String>> onPathsChanged;

  /// Jumlah foto maksimal (default 5 — formulir lapangan).
  final int maxCount;

  /// Nonaktifkan semua aksi (mis. saat submit berjalan).
  final bool enabled;

  /// Awalan Hero tag supaya preview & grid saling terhubung mulus.
  final String heroTagPrefix;

  Future<void> _add(WidgetRef ref) async {
    if (paths.length >= maxCount) return;
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null) return;
    onPathsChanged([...paths, photo.path]);
  }

  Future<void> _retake(WidgetRef ref, int index) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null) return;
    final next = List<String>.from(paths)..[index] = photo.path;
    onPathsChanged(next);
  }

  Future<void> _remove(BuildContext context, int index) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Hapus foto ini?',
      message: 'Foto yang dihapus harus diambil ulang jika masih dibutuhkan.',
      confirmLabel: 'Ya, Hapus',
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed?.confirmed == true) {
      final next = List<String>.from(paths)..removeAt(index);
      onPathsChanged(next);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Foto (${paths.length}/$maxCount)',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (paths.length < maxCount)
              TextButton.icon(
                onPressed: enabled ? () => _add(ref) : null,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Tambah'),
              ),
          ],
        ),
        if (paths.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Belum ada foto. Ketuk "Tambah" untuk mengambil dari kamera.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paths.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final tag = '${heroTagPrefix}_$index';
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => PhotoViewerDialog.show(
                      context: context,
                      heroTag: tag,
                      filePath: paths[index],
                      title: 'Preview Foto ${index + 1}',
                    ),
                    child: Hero(
                      tag: tag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(paths[index]),
                          fit: BoxFit.cover,
                          // Decode cukup untuk grid ~1/3 lebar layar (≈110dp
                          // × dpr 3 ≈ 330px), bukan resolusi kamera penuh.
                          cacheWidth: 400,
                          errorBuilder: (_, _, _) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: enabled ? () => _remove(context, index) : null,
                      child: const _GridOverlayButton(
                        icon: Icons.close,
                        tooltip: 'Hapus foto',
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: InkWell(
                      onTap: enabled ? () => _retake(ref, index) : null,
                      child: const _GridOverlayButton(
                        icon: Icons.cameraswitch_outlined,
                        tooltip: 'Ambil ulang',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _GridOverlayButton extends StatelessWidget {
  const _GridOverlayButton({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}