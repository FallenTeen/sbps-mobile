import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/photo_compression_service.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../produksi/models/production_session.dart';
import '../produksi/produksi_providers.dart';
import 'upload_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';

/// Lampirkan dokumentasi foto produksi/QC (Fase A2.7): pilih 1-10 foto,
/// opsional kaitkan ke sesi produksi (subject_type "ProductionSession"),
/// kirim via outbox — offline = antrean otomatis.
class DokumentasiScreen extends ConsumerStatefulWidget {
  const DokumentasiScreen({super.key});

  @override
  ConsumerState<DokumentasiScreen> createState() => _DokumentasiScreenState();
}

class _DokumentasiScreenState extends ConsumerState<DokumentasiScreen> {
  static const _maksFile = 10;

  final List<String> _paths = [];
  final _catatanCtrl = TextEditingController();
  ProductionSession? _sesi;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pilihFoto() async {
    final sisa = _maksFile - _paths.length;
    if (sisa <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maksimal 10 foto.')));
      return;
    }
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null) return;
    setState(() => _paths.add(photo.path));
  }

  Future<void> _submit() async {
    final result = await ref.read(uploadSubmitProvider.notifier).submitDokumentasi(
          photoPaths: List.of(_paths),
          subjectType:
              _sesi == null ? null : 'ProductionSession',
          subjectId: _sesi?.id,
          catatan: _catatanCtrl.text.trim(),
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.delivered || result.queued) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.delivered
            ? 'Dokumentasi berhasil diunggah.'
            : 'Tersimpan offline — akan dikirim otomatis saat online. Gunakan tombol ☁️ di atas untuk sinkron manual.'),
      ));
      context.pop();
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(uploadSubmitProvider);
    final sesiAktif = ref.watch(sesiAktifProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dokumentasi Produksi'),
        actions: const [PortalSwitchButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(_paths.isEmpty
                ? 'Ambil Foto (1-$_maksFile)'
                : '${_paths.length} foto — ambil lagi'),
            onPressed: busy.busy ? null : _pilihFoto,
          ),
          const SizedBox(height: 12),
          if (_paths.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paths.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemBuilder: (context, i) => Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_paths[i]), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: busy.busy
                          ? null
                          : () async {
                              final confirmed = await ConfirmationDialog.show(
                                context,
                                severity: ConfirmSeverity.warning,
                                title: 'Hapus foto ini?',
                                message: 'Foto yang dihapus harus diambil '
                                    'ulang jika masih dibutuhkan.',
                                confirmLabel: 'Ya, Hapus',
                                icon: Icons.delete_outline_rounded,
                              );
                              if (confirmed?.confirmed == true && mounted) {
                                setState(() => _paths.removeAt(i));
                              }
                            },
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor:
                            Colors.black.withValues(alpha: 0.55),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProductionSession>(
            initialValue: _sesi,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Kaitkan ke sesi produksi (opsional)',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in sesiAktif.value ?? const <ProductionSession>[])
                DropdownMenuItem(
                  value: s,
                  child: Text(
                      '${s.produkNama ?? 'Produk'} — ${s.mesinNama ?? 'Mesin'}'),
                ),
            ],
            onChanged: (v) => setState(() => _sesi = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _catatanCtrl,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Catatan',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: busy.busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(switch (busy.phase) {
              UploadPhase.compressing => 'Mengompres...',
              UploadPhase.sending => 'Mengirim...',
              _ => 'Unggah Dokumentasi',
            }),
            onPressed: busy.busy ? null : _submit,
          ),
        ],
      ),
    );
  }
}
