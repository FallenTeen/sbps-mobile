import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/photo_viewer_dialog.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/photo_compression_service.dart';

import '../presensi/models/presensi_hari_ini.dart';
import '../presensi/presensi_providers.dart';
import 'formulir_providers.dart';
import 'models/formulir_lapangan.dart';
import 'riwayat_formulir_screen.dart';

/// Formulir Lapangan harian (Fase A1.5).
/// - Belum check-in → diblokir dengan pesan jelas.
/// - Sudah terisi hari ini → mode read-only.
/// - Belum diisi → form teks + maks 5 foto, submit via outbox.
class FormulirScreen extends ConsumerWidget {
  const FormulirScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presensiAsync = ref.watch(hariIniProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulir Lapangan'),
        actions: [
          IconButton(
            tooltip: 'Riwayat formulir',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RiwayatFormulirScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: presensiAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonDetailView(),
          ),
          error: (error, _) => _PesanTengah(
            icon: Icons.cloud_off_outlined,
            judul: 'Gagal memuat status presensi',
            detail: '$error',
            aksi: () => ref.invalidate(hariIniProvider),
          ),
          data: (presensi) {
            if (presensi.status == PresensiStatus.belumCheckIn) {
              // Cegah sejak awal — jangan biarkan user mengisi lalu gagal 422.
              return _PesanTengah(
                icon: Icons.login,
                judul: 'Belum check-in hari ini',
                detail:
                    'Formulir lapangan hanya bisa diisi setelah Anda melakukan '
                    'check-in presensi.',
                aksiLabel: 'Kembali',
                aksi: () => Navigator.of(context).maybePop(),
              );
            }
            return const _FormulirBody();
          },
        ),
      ),
    );
  }
}

/// Layar pesan tengah dengan satu aksi (dipakai untuk state terblokir
/// maupun gagal memuat).
class _PesanTengah extends StatelessWidget {
  const _PesanTengah({
    required this.icon,
    required this.judul,
    required this.detail,
    required this.aksi,
    this.aksiLabel = 'Coba lagi',
  });

  final IconData icon;
  final String judul;
  final String detail;
  final VoidCallback aksi;
  final String aksiLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(judul, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: aksi, child: Text(aksiLabel)),
          ],
        ),
      ),
    );
  }
}

class _FormulirBody extends ConsumerWidget {  const _FormulirBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formulirAsync = ref.watch(formulirHariIniProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(formulirHariIniProvider),
      child: formulirAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('Gagal memuat formulir hari ini.'),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(formulirHariIniProvider),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ]),
        data: (formulir) => formulir != null
            ? _FormulirSudahTerisi(formulir)
            : const _FormulirInput(),
      ),
    );
  }
}

// -- Mode sudah terisi (read-only) -------------------------------------------

class _FormulirSudahTerisi extends StatelessWidget {
  const _FormulirSudahTerisi(this.formulir);

  final FormulirLapangan formulir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Formulir hari ini sudah terisi.',
                  style: theme.textTheme.titleMedium),
            ),
          ],
        ),
        if ((formulir.tanggal ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(formulir.tanggal!, style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 12),
        _Baris(label: 'Aktivitas', nilai: formulir.aktivitasDilakukan),
        _Baris(label: 'Kondisi area', nilai: formulir.kondisiArea),
        _Baris(label: 'Kendala', nilai: formulir.kendala),
        _Baris(label: 'Catatan tambahan', nilai: formulir.catatanTambahan),
        if (formulir.foto.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Foto', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: formulir.foto.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, i) =>
                Image.network(formulir.foto[i], fit: BoxFit.cover),
          ),
        ],
      ],
    );
  }
}

class _Baris extends StatelessWidget {
  const _Baris({required this.label, this.nilai});

  final String label;
  final String? nilai;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(nilai == null || nilai!.isEmpty ? '-' : nilai!),
        ],
      ),
    );
  }
}

// -- Form input --------------------------------------------------------------

/// Badge status kecil di thumbnail: kompres (spinner) → siap kirim
/// (centang). State "terkirim" terlihat dari hilangnya thumbnail —
/// setelah sukses layar otomatis pindah ke mode read-only.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({this.phase});

  final UploadPhase? phase;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      UploadPhase.compressing => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      UploadPhase.sending => Icon(Icons.cloud_upload,
          size: 18, color: Theme.of(context).colorScheme.primary),
      null => Icon(Icons.check_circle,
          size: 18, color: Colors.green.shade600),
    };
  }
}

class _FormulirInput extends ConsumerStatefulWidget {
  const _FormulirInput();

  @override
  ConsumerState<_FormulirInput> createState() => _FormulirInputState();
}

class _FormulirInputState extends ConsumerState<_FormulirInput> {
  final _aktivitas = TextEditingController();
  final _kondisi = TextEditingController();
  final _kendala = TextEditingController();
  final _catatan = TextEditingController();

  final _fotoLokal = <String>[];
  static const _maksFoto = 5;

  @override
  void dispose() {
    _aktivitas.dispose();
    _kondisi.dispose();
    _kendala.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _tambahFoto() async {
    final sisa = _maksFoto - _fotoLokal.length;
    if (sisa <= 0) return;
    final picked =
        await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() {
      _fotoLokal.add(picked.path);
    });
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(formulirSubmitProvider.notifier).submit(
          aktivitasDilakukan: _aktivitas.text,
          kondisiArea: _kondisi.text,
          kendala: _kendala.text,
          catatanTambahan: _catatan.text,
          photoPaths: List.unmodifiable(_fotoLokal),
        );

    if (result.delivered) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Formulir berhasil disimpan.')));
    } else if (result.queued) {
      messenger.showSnackBar(const SnackBar(
        content:
            Text('Tersimpan. Menunggu sinkronisasi otomatis saat online.'),
      ));
    } else if (result.error != null && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitState = ref.watch(formulirSubmitProvider);
    final busyPhase = submitState.busy ? submitState.phase : null;
    final busy = busyPhase != null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _aktivitas,
          maxLength: 5000,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Aktivitas dilakukan *',
            hintText: 'Uraikan pekerjaan hari ini...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kondisi,
          maxLength: 2000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Kondisi area',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kendala,
          maxLength: 2000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Kendala',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _catatan,
          maxLength: 2000,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Catatan tambahan',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Foto (${_fotoLokal.length}/$_maksFoto)',
                style: theme.textTheme.labelLarge),
            const Spacer(),
            if (_fotoLokal.length < _maksFoto)
              TextButton.icon(
                onPressed: busy ? null : _tambahFoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Tambah'),
              ),
          ],
        ),
        if (_fotoLokal.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fotoLokal.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, i) {
              final heroTag = 'formulir_draft_photo_$i';
              return Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () => PhotoViewerDialog.show(
                      context: context,
                      heroTag: heroTag,
                      filePath: _fotoLokal[i],
                      title: 'Preview Foto ${i + 1}',
                    ),
                    child: Hero(
                      tag: heroTag,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(File(_fotoLokal[i]), fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  // Indikator 3 state (A1.6): kompres → siap kirim → terkirim
                  // (terkirim ditandai hilangnya thumbnail saat sukses —
                  // layar pindah ke mode read-only).
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: _StatusBadge(phase: busyPhase),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => setState(() => _fotoLokal.removeAt(i)),
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            theme.colorScheme.errorContainer,
                        child: Icon(Icons.close,
                            size: 14,
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        const SizedBox(height: 16),
        BouncingButton(
          onPressed: busy ? null : _submit,
          child: FilledButton.icon(
            onPressed: busy ? null : _submit,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_outlined),
            label: Text(switch (busyPhase) {
              UploadPhase.compressing => 'Mengompres foto...',
              UploadPhase.sending => 'Mengirim...',
              _ => 'Kirim Formulir',
            }),
          ),
        ),
      ],
    );
  }
}
