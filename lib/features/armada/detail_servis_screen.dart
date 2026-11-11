import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../auth/auth_providers.dart';
import 'models/servis_armada.dart';
import 'servis_providers.dart';
import 'servis_status.dart';

/// Detail Pengajuan Servis Armada — menampilkan timeline
/// (Diajukan → Disetujui → Dikerjakan → Selesai), data pengajuan,
/// catatan workshop, sparepart, dan aksi persetujuan/penolakan.
class DetailServisScreen extends StatelessWidget {
  const DetailServisScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const BreadcrumbTitle(
          parentLabel: 'Armada',
          title: 'Detail Servis',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: DetailServisContent(id: id),
      ),
    );
  }
}

/// Konten detail pengajuan servis tanpa Scaffold/AppBar — dipakai sebagai
/// body full-page (lewat [DetailServisScreen]) maupun panel kanan
/// [AdaptiveMasterDetail] saat Expanded.
class DetailServisContent extends ConsumerStatefulWidget {
  const DetailServisContent({required this.id, super.key});

  final String id;

  @override
  ConsumerState<DetailServisContent> createState() =>
      _DetailServisContentState();
}

class _DetailServisContentState extends ConsumerState<DetailServisContent> {
  bool _isProcessing = false;

  Future<void> _approveServis() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Setujui Pengajuan Servis?',
      message:
          'Pengajuan servis akan diteruskan ke tim workshop untuk '
          'dikerjakan.',
      confirmLabel: 'Setujui',
      icon: Icons.check_circle_outline_rounded,
      inputLabel: 'Catatan Persetujuan (opsional)',
      inputRequired: false,
    );

    if (confirm == null || !confirm.confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(servisRepositoryProvider)
          .approveServis(
            id: widget.id,
            catatan: (confirm.reason?.isEmpty ?? true)
                ? null
                : confirm.reason!.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis berhasil disetujui')),
      );
      ref.invalidate(detailServisProvider(widget.id));
      ref.read(servisRiwayatProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              e,
              fallback: 'Gagal menyimpan data servis. Coba lagi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _tolakServis() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.destructive,
      title: 'Tolak Pengajuan Servis?',
      message:
          'Pengajuan ini akan ditolak dan berstatus "Ditolak" secara '
          'permanen. Alasan wajib diisi sebagai catatan keputusan.',
      confirmLabel: 'Tolak Pengajuan',
      icon: Icons.block_rounded,
      inputLabel: 'Alasan Penolakan *',
      inputRequired: true,
    );

    if (confirm == null || !confirm.confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(servisRepositoryProvider)
          .tolakServis(id: widget.id, alasan: confirm.reason ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pengajuan servis ditolak')));
      ref.invalidate(detailServisProvider(widget.id));
      ref.read(servisRiwayatProvider.notifier).refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(
              e,
              fallback: 'Gagal menyimpan data servis. Coba lagi.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _selesaiServis() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Tandai Servis Selesai?',
      message:
          'Pastikan seluruh pengerjaan telah selesai dan unit siap '
          'digunakan kembali.',
      confirmLabel: 'Selesai',
      icon: Icons.check_circle_outline_rounded,
    );
    if (confirm == null || !confirm.confirmed || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(servisRepositoryProvider)
          .selesaiServis(servisId: widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servis berhasil ditandai selesai')),
      );
      ref.invalidate(detailServisProvider(widget.id));
      ref.read(servisRiwayatProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal menyelesaikan servis.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _tambahFotoNota() async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final res = await ref
          .read(servisRepositoryProvider)
          .submitServisEksternalNota(
            servisId: widget.id,
            fotoNotaPaths: [photo.path],
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.delivered ? 'Foto nota berhasil diunggah' : kCopyQueued,
          ),
        ),
      );
      ref.invalidate(detailServisProvider(widget.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal mengunggah foto nota.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _tambahFotoHasil() async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final res = await ref
          .read(servisRepositoryProvider)
          .submitServisFotoHasil(servisId: widget.id, fotoPath: photo.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.delivered
                ? 'Foto hasil pengerjaan berhasil diunggah'
                : kCopyQueued,
          ),
        ),
      );
      ref.invalidate(detailServisProvider(widget.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal mengunggah foto hasil.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(detailServisProvider(widget.id));
    final canApprove = canApproveServis(ref.watch(activeRoleProvider));

    return detailAsync.when(
      loading: () => const SkeletonDetailView(),
      error: (error, _) => Center(
        child: AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal Memuat Detail Servis',
          subtitle: friendlyErrorMessage(error),
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(detailServisProvider(widget.id)),
        ),
      ),
      data: (item) {
        final color = servisStatusColor(item.status, context.colors);

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(detailServisProvider(widget.id)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.platNomor ?? 'Armada #${item.armadaId}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              servisStatusLabel(item.status),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.kodeUnit != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Unit: ${item.kodeUnit!} • Jenis: '
                          '${item.jenisArmada ?? '-'}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (item.isEksternal
                                          ? context.colors.info
                                          : context.colors.primary)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.isEksternal
                                  ? 'Servis Eksternal'
                                  : 'Servis Internal',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: item.isEksternal
                                    ? context.colors.info
                                    : context.colors.primary,
                              ),
                            ),
                          ),
                          if (item.kategori != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                formatKategoriServis(item.kategori!),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          if (item.isEksternal && !item.hasNota)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.warning.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Nota belum lengkap',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.warning,
                                ),
                              ),
                            ),
                          if (item.isEksternal) ...[
                            Builder(
                              builder: (context) {
                                final (verifLabel, verifColor) = switch (item
                                    .verifikasiWorkshop
                                    ?.toLowerCase()) {
                                  'terverifikasi' => (
                                    'Workshop: Terverifikasi',
                                    context.colors.success,
                                  ),
                                  'bermasalah' => (
                                    'Workshop: Bermasalah',
                                    context.colors.error,
                                  ),
                                  _ => (
                                    'Workshop: Belum',
                                    context.colors.textMuted,
                                  ),
                                };
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: verifColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    verifLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: verifColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Timeline
              ServisTimelineCard(item: item),
              const SizedBox(height: 12),

              // Data Pengajuan
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Pengajuan',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(height: 20),
                      _infoRow('Tanggal Ajuan', fmtTanggal(item.tanggalAjuan)),
                      if (item.isEksternal) ...[
                        _infoRow('Tipe Servis', 'Servis Eksternal'),
                        if (item.namaBengkel != null)
                          _infoRow('Bengkel', item.namaBengkel!),
                        if (item.alamatBengkel != null)
                          _infoRow('Alamat Bengkel', item.alamatBengkel!),
                        if (item.latitude != null && item.longitude != null)
                          _infoRow(
                            'GPS Bengkel',
                            '${item.latitude!.toStringAsFixed(6)}, ${item.longitude!.toStringAsFixed(6)}',
                          ),
                        if (item.totalBiayaEstimasi != null)
                          _infoRow(
                            'Estimasi Biaya',
                            fmtRp(item.totalBiayaEstimasi!),
                          ),
                        if (!item.isSelesai)
                          _infoRow('Biaya Resmi', 'Menunggu input via web')
                        else if (item.totalBiayaResmi != null)
                          _infoRow(
                            'Biaya Resmi (Nota)',
                            fmtRp(item.totalBiayaResmi!),
                          )
                        else
                          _infoRow('Biaya Resmi', 'Belum tersedia'),
                        if (item.rincianPekerjaan != null &&
                            item.rincianPekerjaan!.isNotEmpty)
                          _infoRow('Rincian Pekerjaan', item.rincianPekerjaan!),
                        if (item.verifikasiWorkshopCatatan != null &&
                            item.verifikasiWorkshopCatatan!.isNotEmpty)
                          _infoRow(
                            'Catatan Workshop',
                            item.verifikasiWorkshopCatatan!,
                          ),
                      ],
                      if (item.kategori != null)
                        _infoRow(
                          'Kategori',
                          formatKategoriServis(item.kategori!),
                        ),
                      if (item.odometerSaatAjuan != null)
                        _infoRow(
                          'ODO Saat Ajuan',
                          fmtKm(item.odometerSaatAjuan),
                        ),
                      if (item.jamOperasionalSaatAjuan != null)
                        _infoRow(
                          'Jam Operasional',
                          fmtJam(item.jamOperasionalSaatAjuan),
                        ),
                      if (item.diajukanOleh != null)
                        _infoRow('Diajukan Oleh', item.diajukanOleh!),
                      if (item.disetujuiOleh != null)
                        _infoRow('Disetujui Oleh', item.disetujuiOleh!),
                      if (item.tanggalSelesai != null)
                        _infoRow(
                          'Tanggal Selesai',
                          fmtTanggal(item.tanggalSelesai),
                        ),
                      if (item.catatanWorkshop != null) ...[
                        _infoRow('Catatan Workshop', item.catatanWorkshop!),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Keluhan / Masalah:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(item.keluhan),
                      ),
                      if (item.alasanPenolakan != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Alasan Penolakan:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(item.alasanPenolakan!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sparepart yang digunakan (jika ada)
              if (item.spareparts.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sparepart Digunakan',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Chip(
                              label: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${item.spareparts.length} item',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        for (final part in item.spareparts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    part.namaBarang,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${part.jumlah.toStringAsFixed(0)} '
                                  '${part.satuan ?? 'pcs'}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (item.totalBiaya != null) ...[
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Biaya:',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                fmtRp(item.totalBiaya!),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.success,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Action Buttons for Approval (if status is 'diajukan')
              if (item.isEksternal) ...[
                // Foto Bengkel Card
                if (item.fotoBengkelUrl != null &&
                    item.fotoBengkelUrl!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto Bengkel',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Divider(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.fotoBengkelUrl!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                height: 120,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image, size: 36),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Foto Nota Card (TD-B4)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Foto Nota (${item.fotoNotaUrls.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextButton.icon(
                              onPressed: _isProcessing ? null : _tambahFotoNota,
                              icon: const Icon(Icons.add_a_photo, size: 16),
                              label: const Text('Tambah Nota'),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (item.fotoNotaUrls.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Belum ada foto nota. Driver dapat menambahkan foto nota di sini, '
                              'dan menyetor nota fisik ke Ketua Armada / Keuangan.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textTertiary,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final url in item.fotoNotaUrls)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Foto Hasil Pengerjaan Card (TD-B4, TD-B5)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Foto Hasil (${item.fotoHasilUrls.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextButton.icon(
                              onPressed: _isProcessing
                                  ? null
                                  : _tambahFotoHasil,
                              icon: const Icon(Icons.camera_alt, size: 16),
                              label: const Text('Tambah Foto Hasil'),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        if (item.fotoHasilUrls.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Foto hasil pengerjaan bersifat opsional.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textTertiary,
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final url in item.fotoHasilUrls)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.broken_image,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Action Selesai untuk Driver (TD-B3)
                if (item.isDikerjakan) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: BouncingButton(
                      onPressed: _isProcessing ? null : _selesaiServis,
                      child: FilledButton.icon(
                        onPressed: _isProcessing ? null : _selesaiServis,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: const Text('Tandai Pengerjaan Selesai'),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.colors.success,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],

              // Action Buttons for Approval (Internal service - if status is 'diajukan')
              if (item.isMenungguApproval && canApprove) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BouncingButton(
                        onPressed: _isProcessing ? null : _tolakServis,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _tolakServis,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.close),
                          label: const Text('Tolak'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BouncingButton(
                        onPressed: _isProcessing ? null : _approveServis,
                        child: FilledButton.icon(
                          onPressed: _isProcessing ? null : _approveServis,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: const Text('Setujui'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kolom label dan tanda titik dua konsisten agar nilai sejajar.
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Text(':'),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

/// Timeline servis: Diajukan → Disetujui → Dikerjakan → Selesai, plus node
/// terminal "Ditolak" bila pengajuan ditolak.
class ServisTimelineCard extends StatelessWidget {
  const ServisTimelineCard({required this.item, super.key});

  final ServisArmada item;

  @override
  Widget build(BuildContext context) {
    final steps = servisTimelineSteps(item);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline Servis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(height: 20),
            for (var i = 0; i < steps.length; i++) ...[
              _TimelineNode(step: steps[i], caption: _captionFor(i)),
              if (i != steps.length - 1) _StepConnector(state: steps[i].state),
            ],
          ],
        ),
      ),
    );
  }

  /// Fakta yang tersedia dari API (tidak mengarang tanggal antar-status).
  String? _captionFor(int index) {
    if (index == 0) {
      final tanggal = fmtTanggal(item.tanggalAjuan);
      return item.diajukanOleh == null
          ? tanggal
          : '$tanggal • ${item.diajukanOleh}';
    }
    if (index == 1) return item.disetujuiOleh;
    if (index == 2) return item.catatanWorkshop;
    if (index == 3) {
      return item.tanggalSelesai == null
          ? null
          : fmtTanggal(item.tanggalSelesai);
    }
    // Node terminal "Ditolak": alasan penolakan sebagai caption.
    return item.alasanPenolakan;
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({required this.step, this.caption});

  final ServisTimelineStep step;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      ServisTimelineState.done => context.colors.success,
      ServisTimelineState.current => context.colors.primary,
      ServisTimelineState.pending => Theme.of(
        context,
      ).colorScheme.outlineVariant,
      ServisTimelineState.rejected => context.colors.error,
    };
    final icon = switch (step.state) {
      ServisTimelineState.done => Icons.check_rounded,
      ServisTimelineState.current => Icons.circle,
      ServisTimelineState.pending => Icons.circle_outlined,
      ServisTimelineState.rejected => Icons.block_rounded,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.label,
                  style: TextStyle(
                    fontWeight: step.state == ServisTimelineState.current
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: step.state == ServisTimelineState.pending
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : color,
                  ),
                ),
                if (caption != null && caption!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector({required this.state});

  final ServisTimelineState state;

  @override
  Widget build(BuildContext context) {
    final done = state == ServisTimelineState.done;
    final color = done
        ? context.colors.success
        : Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Container(width: 2, height: 18, color: color),
    );
  }
}
