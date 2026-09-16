import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analytics_service.dart';
import '../../core/draft/autosave_controller.dart';
import '../../core/draft/draft_repository.dart';
import '../../core/photo_compression_service.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/draft_restore_banner.dart';
import '../../shared/widgets/form_section.dart';
import '../../shared/widgets/key_value_row.dart';
import '../../shared/widgets/photo_grid_editor.dart';
import '../../shared/widgets/photo_viewer_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/sticky_action_bar.dart';
import '../presensi/models/presensi_hari_ini.dart';
import '../presensi/presensi_providers.dart';
import 'formulir_providers.dart';
import 'models/formulir_lapangan.dart';
import 'riwayat_formulir_screen.dart';

void _openRiwayat(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const RiwayatFormulirScreen()),
  );
}

String _formatToday(DateTime now) => DateFormat('d MMM y', 'id_ID').format(now);

String? _fmtIsoTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return DateFormat('HH:mm', 'id_ID').format(dt);
}

String _presensiStatusLabel(PresensiStatus status) => switch (status) {
  PresensiStatus.belumCheckIn => 'Belum Check-In',
  PresensiStatus.menungguCheckOut => 'Sedang Bekerja',
  PresensiStatus.selesai => 'Selesai',
};

/// Status laporan untuk kartu index — menjelaskan "langkah apa berikutnya".
enum _ReportStatus { belumDiisi, menungguSinkron, selesai }

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
              onPressed: () => _openRiwayat(context),
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
              subtitle: friendlyErrorMessage(error),
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
    return formulir.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            child: AppEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Gagal memuat formulir hari ini',
              subtitle: friendlyErrorMessage(error),
              actionLabel: 'Coba Lagi',
              onAction: () => ref.invalidate(formulirHariIniProvider),
            ),
          ),
        ],
      ),
      data: (value) {
        final presensi = ref.watch(hariIniProvider).value;
        final menunggu = value == null && ref.watch(pendingFormulirProvider);
        if (menunggu) {
          return _FormulirMenungguSinkron(presensi: presensi);
        }
        if (value == null) {
          return _FormulirEditor(presensi: presensi);
        }
        return _FormulirSudahTerisi(formulir: value, presensi: presensi);
      },
    );
  }
}

/// Kartu index — "Laporan Lapangan Hari Ini": laporan hari ini, jumlah
/// lengkap/belum lengkap, titik, tanggal, status, dan next action.
/// Jangan menampilkan daftar record tanpa konteks.
class _LaporanIndexCard extends StatelessWidget {
  const _LaporanIndexCard({
    required this.status,
    this.presensi,
    this.onIsiLaporan,
  });

  final _ReportStatus status;
  final PresensiHariIni? presensi;

  /// Dipasang saat status [belumDiisi] → fokus ke field Aktivitas.
  final VoidCallback? onIsiLaporan;

  (String, Color) _badge(BuildContext context) {
    final colors = context.colors;
    return switch (status) {
      _ReportStatus.belumDiisi => ('Belum Diisi', colors.warning),
      _ReportStatus.menungguSinkron => (
        'Menunggu Sinkron',
        Theme.of(context).colorScheme.tertiary,
      ),
      _ReportStatus.selesai => ('Selesai', colors.success),
    };
  }

  String get _nextAction => switch (status) {
    _ReportStatus.belumDiisi =>
      'Lengkapi laporan aktivitas & kondisi lokasi agar tercatat hari ini.',
    _ReportStatus.menungguSinkron =>
      'Laporan tersimpan di perangkat; otomatis terkirim saat jaringan tersedia.',
    _ReportStatus.selesai => 'Laporan hari ini sudah lengkap dan tersimpan.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (badgeLabel, badgeColor) = _badge(context);
    final lengkap = status == _ReportStatus.selesai;
    final titik = presensi?.titik?.nama ?? '-';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.shadowLv1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Laporan Lapangan Hari Ini',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(label: badgeLabel, color: badgeColor),
              ],
            ),
            const SizedBox(height: 6),
            KeyValueRow(
              label: 'Jumlah Lengkap',
              value: lengkap ? '1' : '0',
              valueIsImportant: true,
              valueColor: lengkap
                  ? context.colors.success
                  : context.colors.textPrimary,
            ),
            KeyValueRow(
              label: 'Jumlah Belum Lengkap',
              value: lengkap ? '0' : '1',
              valueIsImportant: true,
            ),
            KeyValueRow(label: 'Titik', value: titik),
            KeyValueRow(label: 'Tanggal', value: _formatToday(DateTime.now())),
            const SizedBox(height: 4),
            Text(
              _nextAction,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            if (onIsiLaporan != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onIsiLaporan,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Isi Laporan'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FormulirMenungguSinkron extends ConsumerWidget {
  const _FormulirMenungguSinkron({this.presensi});

  final PresensiHariIni? presensi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(formulirHariIniProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _LaporanIndexCard(
            status: _ReportStatus.menungguSinkron,
            presensi: presensi,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FormSection(
              title: 'Status Sinkron',
              children: [
                Text(
                  'Formulir Anda sudah tersimpan di perangkat dan akan '
                  'otomatis dikirim ke server saat jaringan tersedia.',
                ),
                const SizedBox(height: 8),
                const KeyValueRow(label: 'Status', value: 'Menunggu Sinkron'),
                const KeyValueRow(label: 'Tindakan', value: 'Tidak perlu diisi ulang'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulirSudahTerisi extends ConsumerWidget {
  const _FormulirSudahTerisi({required this.formulir, this.presensi});

  final FormulirLapangan formulir;
  final PresensiHariIni? presensi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(formulirHariIniProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _LaporanIndexCard(status: _ReportStatus.selesai, presensi: presensi),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FormSection(
              title: 'Laporan Hari Ini',
              children: [
                if ((formulir.titik ?? '').isNotEmpty)
                  KeyValueRow(label: 'Titik', value: formulir.titik!),
                if ((formulir.tanggal ?? '').isNotEmpty)
                  KeyValueRow(label: 'Tanggal', value: formulir.tanggal!),
                if ((formulir.aktivitasDilakukan ?? '').isNotEmpty)
                  KeyValueRow(label: 'Aktivitas', value: formulir.aktivitasDilakukan!),
                if ((formulir.kondisiArea ?? '').isNotEmpty)
                  KeyValueRow(label: 'Kondisi Area', value: formulir.kondisiArea!),
                if ((formulir.kendala ?? '').isNotEmpty)
                  KeyValueRow(label: 'Kendala', value: formulir.kendala!),
                if ((formulir.catatanTambahan ?? '').isNotEmpty)
                  KeyValueRow(label: 'Catatan Tambahan', value: formulir.catatanTambahan!),
                if (formulir.foto.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Foto (${formulir.foto.length})',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NetworkPhotoGrid(urls: formulir.foto),
                ],
              ],
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () => _openRiwayat(context),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Lihat Riwayat'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkPhotoGrid extends StatelessWidget {
  const _NetworkPhotoGrid({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, i) {
        final tag = 'formulir_submitted_photo_$i';
        return GestureDetector(
          onTap: () => PhotoViewerDialog.show(
            context: context,
            heroTag: tag,
            imageUrl: urls[i],
            title: 'Foto ${i + 1}',
          ),
          child: Hero(
            tag: tag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                urls[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined, size: 20),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FormulirEditor extends ConsumerStatefulWidget {
  const _FormulirEditor({this.presensi});

  final PresensiHariIni? presensi;

  @override
  ConsumerState<_FormulirEditor> createState() => _FormulirEditorState();
}

class _FormulirEditorState extends ConsumerState<_FormulirEditor> {
  static const _maxFoto = 5;

  final _aktivitas = TextEditingController();
  final _kondisi = TextEditingController();
  final _kendala = TextEditingController();
  final _catatan = TextEditingController();
  final _aktivitasFocus = FocusNode();
  final _foto = <String>[];

  bool _adaKendala = false;
  bool _draftFound = false;
  DateTime? _draftSavedAt;
  bool _aktivitasError = false;
  bool _kendalaError = false;

  final _aktivitasKey = GlobalKey();
  final _kendalaKey = GlobalKey();

  late final AutosaveController _autosave;

  Map<String, dynamic> _snapshot() => {
    'aktivitas': _aktivitas.text,
    'kondisi': _kondisi.text,
    'kendala': _kendala.text,
    'catatan': _catatan.text,
    'adaKendala': _adaKendala,
  };

  void _restoreFromDraft(FormDraft draft) {
    final fields = draft.fieldsJson;
    _aktivitas.text = fields['aktivitas'] as String? ?? '';
    _kondisi.text = fields['kondisi'] as String? ?? '';
    _kendala.text = fields['kendala'] as String? ?? '';
    _catatan.text = fields['catatan'] as String? ?? '';
    _adaKendala = fields['adaKendala'] as bool? ?? false;
    _foto
      ..clear()
      ..addAll(draft.photoLocalPaths);
    setState(() {
      _draftFound = true;
      _draftSavedAt = draft.savedAt;
    });
  }

  @override
  void initState() {
    super.initState();
    _autosave = AutosaveController(
      ref: ref,
      draftKey: 'formulir_lapangan',
      formType: DraftFormType.formulirLapangan,
      currentFields: _snapshot,
      currentPhotoPaths: () => List.unmodifiable(_foto),
      onRestore: _restoreFromDraft,
    );
    _autosave.init();

    _aktivitas.addListener(_aktivitasChanged);
    _kondisi.addListener(_kondisiChanged);
    _kendala.addListener(_kendalaChanged);
    _catatan.addListener(_catatanChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _autosave.load());
  }

  @override
  void dispose() {
    _autosave.dispose();
    _aktivitas.dispose();
    _kondisi.dispose();
    _kendala.dispose();
    _catatan.dispose();
    _aktivitasFocus.dispose();
    super.dispose();
  }

  void _aktivitasChanged() {
    if (_aktivitasError) setState(() => _aktivitasError = false);
    _autosave.onFieldChanged();
  }

  void _kendalaChanged() {
    if (_kendalaError) setState(() => _kendalaError = false);
    _autosave.onFieldChanged();
  }

  void _kondisiChanged() => _autosave.onFieldChanged();

  void _catatanChanged() => _autosave.onFieldChanged();

  void _setAdaKendala(bool value) {
    setState(() {
      _adaKendala = value;
      if (!value) _kendalaError = false;
    });
    _autosave.onFieldChanged();
  }

  void _setFoto(List<String> next) {
    if (!mounted) return;
    setState(() {
      _foto
        ..clear()
        ..addAll(next);
    });
    _autosave.onFieldChanged();
  }

  bool get _hasDraft =>
      _aktivitas.text.trim().isNotEmpty ||
      _kondisi.text.trim().isNotEmpty ||
      _kendala.text.trim().isNotEmpty ||
      _catatan.text.trim().isNotEmpty ||
      _foto.isNotEmpty;

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _focusAktivitas() {
    _scrollToKey(_aktivitasKey);
    _aktivitasFocus.requestFocus();
  }

  Future<void> _confirmDiscardDraft() async {
    final confirm = await ConfirmationDialog.show(
      context,
      severity: ConfirmSeverity.warning,
      title: 'Keluar tanpa menyimpan?',
      message:
          'Draft formulir yang belum dikirim akan hilang. Lanjutkan keluar?',
      confirmLabel: 'Ya, Keluar',
      icon: Icons.arrow_back_rounded,
    );
    if (confirm?.confirmed == true && mounted) {
      await _autosave.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    if (ref.read(pendingFormulirProvider)) return;

    final aktivitasValid = _aktivitas.text.trim().isNotEmpty;
    final kendalaValid = !_adaKendala || _kendala.text.trim().isNotEmpty;
    setState(() {
      _aktivitasError = !aktivitasValid;
      _kendalaError = !kendalaValid;
    });
    if (!aktivitasValid) {
      _scrollToKey(_aktivitasKey);
      return;
    }
    if (!kendalaValid) {
      _scrollToKey(_kendalaKey);
      return;
    }

    final result = await ref
        .read(formulirSubmitProvider.notifier)
        .submit(
          aktivitasDilakukan: _aktivitas.text,
          kondisiArea: _kondisi.text,
          kendala: _adaKendala ? _kendala.text : null,
          catatanTambahan: _catatan.text,
          photoPaths: List.unmodifiable(_foto),
        );
    AnalyticsService.formulirSubmit();
    await _autosave.clear();
    if (!mounted) return;
    final message = result.delivered
        ? 'Formulir berhasil disimpan.'
        : result.queued
        ? kCopyQueued
        : result.error ?? 'Formulir gagal disimpan.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _submitLabel(UploadPhase? phase) => switch (phase) {
    UploadPhase.compressing => 'Mengompres foto...',
    UploadPhase.sending => 'Mengirim...',
    _ => 'Kirim Formulir',
  };

  Widget _textEditor({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int minLines,
    required int maxLines,
    required int maxLength,
    bool required = false,
    String? error,
    Key? fieldKey,
  }) {
    return Semantics(
      label: hint,
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: controller == _aktivitas ? _aktivitasFocus : null,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          helperText: required ? 'Wajib diisi' : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _seksiKonteks() {
    final checkIn = widget.presensi?.checkIn;
    final titik = widget.presensi?.titik?.nama ?? '-';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: FormSection(
        title: 'Konteks',
        children: [
          KeyValueRow(label: 'Titik', value: titik),
          KeyValueRow(label: 'Tanggal', value: _formatToday(DateTime.now())),
          if (widget.presensi != null)
            KeyValueRow(
              label: 'Presensi',
              value: _presensiStatusLabel(widget.presensi!.status),
            ),
          if (checkIn != null)
            KeyValueRow(label: 'Check-in', value: _fmtIsoTime(checkIn) ?? checkIn),
        ],
      ),
    );
  }

  Widget _seksiAktivitas() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: FormSection(
      title: 'Aktivitas',
      children: [
        _textEditor(
          controller: _aktivitas,
          label: 'Aktivitas dilakukan *',
          hint: 'Kegiatan yang dilakukan di titik kerja',
          minLines: 3,
          maxLines: 6,
          maxLength: 5000,
          required: true,
          error: _aktivitasError ? 'Uraikan aktivitas yang dilakukan.' : null,
          fieldKey: _aktivitasKey,
        ),
      ],
    ),
  );

  Widget _seksiKondisi() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: FormSection(
      title: 'Kondisi Area',
      children: [
        _textEditor(
          controller: _kondisi,
          label: 'Kondisi area',
          hint: 'Kondisi lokasi/lingkungan kerja saat ini',
          minLines: 2,
          maxLines: 4,
          maxLength: 2000,
        ),
      ],
    ),
  );

  Widget _seksiKendala() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: FormSection(
      title: 'Kendala',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Tidak ada'),
              selected: !_adaKendala,
              onSelected: (_) => _setAdaKendala(false),
            ),
            ChoiceChip(
              label: const Text('Ada kendala'),
              selected: _adaKendala,
              onSelected: (_) => _setAdaKendala(true),
            ),
          ],
        ),
        if (_adaKendala) ...[
          const SizedBox(height: 4),
          _textEditor(
            controller: _kendala,
            label: 'Kendala *',
            hint: 'Jelaskan hambatan yang ditemui di lokasi',
            minLines: 2,
            maxLines: 4,
            maxLength: 2000,
            required: true,
            error: _kendalaError ? 'Kendala wajib diisi bila memilih "Ada kendala".' : null,
            fieldKey: _kendalaKey,
          ),
        ],
      ],
    ),
  );

  Widget _seksiCatatan() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: FormSection(
      title: 'Catatan',
      children: [
        _textEditor(
          controller: _catatan,
          label: 'Catatan tambahan',
          hint: 'Informasi tambahan yang perlu dicatat',
          minLines: 2,
          maxLines: 4,
          maxLength: 2000,
        ),
      ],
    ),
  );

  Widget _seksiDokumentasi(
    BuildContext context,
    bool busy,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: FormSection(
        title: 'Dokumentasi',
        children: [
          Text(
            'Foto kegiatan & kondisi lokasi (opsional, maks $_maxFoto).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.colors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          PhotoGridEditor(
            paths: _foto,
            onPathsChanged: _setFoto,
            maxCount: _maxFoto,
            enabled: !busy,
            heroTagPrefix: 'formulir_draft_photo',
          ),
        ],
      ),
    );
  }

  Widget _seksiReview() {
    final theme = Theme.of(context);
    final reviewAktivitas = _aktivitas.text.trim();
    final reviewKondisi = _kondisi.text.trim();
    final reviewKendala = _kendala.text.trim().isNotEmpty
        ? _kendala.text.trim()
        : (_adaKendala ? 'Belum diisi' : 'Tidak ada');
    final reviewCatatan = _catatan.text.trim();
    final formReady =
        reviewAktivitas.isNotEmpty &&
        (!_adaKendala || _kendala.text.trim().isNotEmpty);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: FormSection(
        title: 'Review',
        children: [
          KeyValueRow(
            label: 'Aktivitas',
            value: reviewAktivitas.isEmpty ? 'Belum diisi' : reviewAktivitas,
            valueColor: reviewAktivitas.isEmpty
                ? context.colors.textTertiary
                : null,
          ),
          KeyValueRow(
            label: 'Kondisi area',
            value: reviewKondisi.isEmpty ? '—' : reviewKondisi,
          ),
          KeyValueRow(label: 'Kendala', value: reviewKendala),
          KeyValueRow(
            label: 'Catatan tambahan',
            value: reviewCatatan.isEmpty ? '—' : reviewCatatan,
          ),
          KeyValueRow(label: 'Dokumentasi', value: '${_foto.length} foto'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                formReady
                    ? Icons.check_circle_outline
                    : Icons.pending_actions_outlined,
                size: 18,
                color: formReady
                    ? context.colors.success
                    : context.colors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formReady
                      ? 'Laporan siap dikirim.'
                      : 'Lengkapi bidang wajib sebelum mengirim.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitState = ref.watch(formulirSubmitProvider);
    final busyPhase = submitState.busy ? submitState.phase : null;
    final busy = busyPhase != null;

    return PopScope(
      canPop: !_hasDraft,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (busy) return;
        _confirmDiscardDraft();
      },
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(formulirHariIniProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _LaporanIndexCard(
                    status: _ReportStatus.belumDiisi,
                    presensi: widget.presensi,
                    onIsiLaporan: _focusAktivitas,
                  ),
                  if (_draftFound)
                    DraftRestoreBanner(
                      savedAt: _draftSavedAt ?? DateTime.now(),
                      onContinue: () => setState(() => _draftFound = false),
                      onDiscard: () async {
                        await _autosave.clear();
                        if (!mounted) return;
                        setState(() {
                          _draftFound = false;
                          _aktivitas.clear();
                          _kondisi.clear();
                          _kendala.clear();
                          _catatan.clear();
                          _adaKendala = false;
                          _foto.clear();
                        });
                      },
                      warning:
                          'Data foto mungkin sudah tidak sesuai kondisi terkini, '
                          'disarankan periksa ulang sebelum submit.',
                    ),
                  _seksiKonteks(),
                  _seksiAktivitas(),
                  _seksiKondisi(),
                  _seksiKendala(),
                  _seksiCatatan(),
                  _seksiDokumentasi(context, busy),
                  _seksiReview(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      'Draft tersimpan otomatis di perangkat — aman bila '
                      'aplikasi tertutup.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyActionBar(
            primaryLabel: _submitLabel(busyPhase),
            primaryIcon: Icons.send_outlined,
            onPrimary: busy ? () {} : _submit,
            showPrimaryLoading: submitState.busy,
          ),
        ],
      ),
    );
  }
}