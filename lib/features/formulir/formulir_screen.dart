import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/photo_compression_service.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/photo_viewer_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../presensi/models/presensi_hari_ini.dart';
import '../presensi/presensi_providers.dart';
import 'formulir_providers.dart';
import 'models/formulir_lapangan.dart';
import 'riwayat_formulir_screen.dart';

class FormulirScreen extends ConsumerWidget {
  const FormulirScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presensi = ref.watch(hariIniProvider);
    return Semantics(
      label: 'Formulir Lapangan, aplikasi presensi lapangan SBPS',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Formulir Lapangan'),
          actions: [
            const PortalSwitchButton(),
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
          child: presensi.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonDetailView(),
            ),
            error: (error, _) => AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Gagal memuat status presensi',
              subtitle: '$error',
              actionLabel: 'Coba lagi',
              onAction: () => ref.invalidate(hariIniProvider),
            ),
            data: (value) => value.status == PresensiStatus.belumCheckIn
                ? AppEmptyState(
                    icon: Icons.login,
                    title: 'Belum check-in hari ini',
                    subtitle:
                        'Formulir lapangan hanya bisa diisi setelah Anda '
                        'melakukan check-in presensi.',
                    actionLabel: 'Kembali',
                    onAction: () => Navigator.of(context).maybePop(),
                  )
                : const _FormulirBody(),
          ),
        ),
      ),
    );
  }
}

class _FormulirBody extends ConsumerWidget {
  const _FormulirBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formulir = ref.watch(formulirHariIniProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(formulirHariIniProvider),
      child: formulir.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('Gagal memuat formulir hari ini.'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => ref.invalidate(formulirHariIniProvider),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (value) => value == null
            ? const _FormulirInput()
            : _FormulirSudahTerisi(value),
      ),
    );
  }
}

class _FormulirSudahTerisi extends StatelessWidget {
  const _FormulirSudahTerisi(this.formulir);

  final FormulirLapangan formulir;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Formulir hari ini sudah terisi.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if ((formulir.tanggal ?? '').isNotEmpty) Text(formulir.tanggal!),
        const SizedBox(height: 12),
        _ValueRow('Aktivitas', formulir.aktivitasDilakukan),
        _ValueRow('Kondisi area', formulir.kondisiArea),
        _ValueRow('Kendala', formulir.kendala),
        _ValueRow('Catatan tambahan', formulir.catatanTambahan),
        if (formulir.foto.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Foto'),
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
            itemBuilder: (context, index) =>
                Image.network(formulir.foto[index], fit: BoxFit.cover),
          ),
        ],
      ],
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          Text(value == null || value!.isEmpty ? '-' : value!),
        ],
      ),
    );
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
  final _foto = <String>[];
  static const _maxFoto = 5;

  @override
  void dispose() {
    _aktivitas.dispose();
    _kondisi.dispose();
    _kendala.dispose();
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_foto.length >= _maxFoto) return;
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null || !mounted) return;
    setState(() => _foto.add(photo.path));
  }

  Future<void> _submit() async {
    final result = await ref
        .read(formulirSubmitProvider.notifier)
        .submit(
          aktivitasDilakukan: _aktivitas.text,
          kondisiArea: _kondisi.text,
          kendala: _kendala.text,
          catatanTambahan: _catatan.text,
          photoPaths: List.unmodifiable(_foto),
        );
    AnalyticsService.formulirSubmit();
    if (!mounted) return;
    final message = result.delivered
        ? 'Formulir berhasil disimpan.'
        : result.queued
        ? 'Tersimpan offline - akan dikirim otomatis saat online.'
        : result.error ?? 'Formulir gagal disimpan.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(formulirSubmitProvider);
    final busyPhase = submitState.busy ? submitState.phase : null;
    final busy = busyPhase != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _field(
          _aktivitas,
          'Aktivitas dilakukan *',
          'Aktivitas dilakukan',
          3,
          6,
          5000,
        ),
        const SizedBox(height: 12),
        _field(_kondisi, 'Kondisi area', 'Kondisi area', 2, 4, 2000),
        const SizedBox(height: 12),
        _field(_kendala, 'Kendala', 'Kendala', 2, 4, 2000),
        const SizedBox(height: 12),
        _field(_catatan, 'Catatan tambahan', 'Catatan tambahan', 2, 4, 2000),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Foto (${_foto.length}/$_maxFoto)'),
            const Spacer(),
            if (_foto.length < _maxFoto)
              TextButton.icon(
                onPressed: busy ? null : _addPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Tambah'),
              ),
          ],
        ),
        if (_foto.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _foto.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final tag = 'formulir_draft_photo_$index';
              return GestureDetector(
                onTap: () => PhotoViewerDialog.show(
                  context: context,
                  heroTag: tag,
                  filePath: _foto[index],
                  title: 'Preview Foto ${index + 1}',
                ),
                child: Hero(
                  tag: tag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(_foto[index]), fit: BoxFit.cover),
                  ),
                ),
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
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
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

  Widget _field(
    TextEditingController controller,
    String label,
    String semanticsLabel,
    int minLines,
    int maxLines,
    int maxLength,
  ) {
    return Semantics(
      label: semanticsLabel,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
