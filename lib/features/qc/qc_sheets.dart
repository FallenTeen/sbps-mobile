import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import 'qc_providers.dart';
import 'qc_rules.dart';

/// Konteks produksi yang sedang diperiksa — ditampilkan SEBELUM input hasil
/// supaya petugas tahu persis apa yang sedang diuji.
class QcInspectionContext {
  const QcInspectionContext({
    this.produkNama,
    this.mesinNama,
    this.titikNama,
    this.mulai,
    this.jenisUji = 'slump_test',
    this.tanggalUjiTekanRencana,
  });

  final String? produkNama;
  final String? mesinNama;
  final String? titikNama;
  final DateTime? mulai;
  final String jenisUji;
  final String? tanggalUjiTekanRencana;
}

enum _QcPhase { input, review }

/// Kartu konteks produksi — menjawab "apa yang sedang diperiksa".
class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.context, required this.icon});

  final QcInspectionContext context;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctx = this.context;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Sedang Diperiksa',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ctxRow(theme, 'Produk', ctx.produkNama ?? '-'),
          _ctxRow(theme, 'Mesin', ctx.mesinNama ?? '-'),
          _ctxRow(theme, 'Titik', ctx.titikNama ?? '-'),
          _ctxRow(theme, 'Waktu mulai', fmtTanggalWaktu(ctx.mulai)),
          if (ctx.jenisUji == 'uji_tekan' &&
              ctx.tanggalUjiTekanRencana != null)
            _ctxRow(theme, 'Rencana tekan', ctx.tanggalUjiTekanRencana!),
        ],
      ),
    );
  }

  Widget _ctxRow(ThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Strip catatan hasil — hanya parafrase jujur, TIDAK menghitung formula.
class _ResultNote extends StatelessWidget {
  const _ResultNote({required this.text, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.info),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

/// Bottom sheet "Catat Slump Test" (Fase A2.5 + Phase 14):
/// Context → Actual → Catatan → Result → Review → Submit.
class SlumpTestSheet extends ConsumerStatefulWidget {
  const SlumpTestSheet({
    super.key,
    required this.sessionId,
    required this.context,
  });

  final String sessionId;
  final QcInspectionContext context;

  @override
  ConsumerState<SlumpTestSheet> createState() => _SlumpTestSheetState();
}

class _SlumpTestSheetState extends ConsumerState<SlumpTestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nilaiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  _QcPhase _phase = _QcPhase.input;

  @override
  void dispose() {
    _nilaiCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  double? get _nilai =>
      double.tryParse(_nilaiCtrl.text.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    final result = await ref
        .read(qcSubmitProvider.notifier)
        .slumpTest(
          sessionId: widget.sessionId,
          nilaiSlump: double.parse(_nilaiCtrl.text.replaceAll(',', '.')),
          catatan: _catatanCtrl.text.trim(),
        );

    AnalyticsService.qcSlumpSubmit();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (result.delivered || result.queued) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.delivered
                ? 'Slump test dicatat — menunggu hasil uji tekan.'
                : kCopyQueued,
          ),
        ),
      );
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(qcSubmitProvider).busy;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catat Slump Test',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.context.produkNama ?? 'Produk'} — '
                '${widget.context.mesinNama ?? 'Mesin'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _ContextCard(context: widget.context, icon: Icons.science_outlined),
              const SizedBox(height: 12),
              if (_phase == _QcPhase.input) ...[
                TextFormField(
                  controller: _nilaiCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Nilai slump (Actual) *',
                    suffixText: 'mm',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => validateNilaiWajib(v ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _catatanCtrl,
                  maxLines: 2,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                _ResultNote(
                  icon: Icons.move_to_inbox_outlined,
                  text: 'Setelah dicatat, sampel masuk antrean — status '
                      '"Menunggu hasil" sampai hasil uji tekan direkam.',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _phase = _QcPhase.review);
                      }
                    },
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Lanjut ke Review'),
                  ),
                ),
              ] else ...[
                _buildReview(context),
                const SizedBox(height: 12),
                _ResultNote(
                  icon: Icons.hourglass_empty_rounded,
                  text: 'Hasil: nilai slump ${_fmt(_nilai)} mm '
                      '(status "Menunggu hasil" sampai uji tekan direkam).',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => _phase = _QcPhase.input),
                        child: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: Text(busy ? 'Menyimpan...' : 'Simpan Hasil'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _ReviewRow(
            label: 'Sample slump',
            value: 'Slump Test',
          ),
          _ReviewRow(
            label: 'Nilai (Actual)',
            value: '${_fmt(_nilai)} mm',
          ),
          _ReviewRow(
            label: 'Catatan',
            value: _catatanCtrl.text.trim().isEmpty
                ? '-'
                : _catatanCtrl.text.trim(),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet "Catat Uji Tekan" — sesi harus punya sample slump yang
/// masih menunggu hasil. Phase 14 flow:
/// Context → Target → Actual → Catatan → Result → Review → Submit.
class UjiTekanSheet extends ConsumerStatefulWidget {
  const UjiTekanSheet({
    super.key,
    required this.sessionId,
    required this.context,
  });

  final String sessionId;
  final QcInspectionContext context;

  @override
  ConsumerState<UjiTekanSheet> createState() => _UjiTekanSheetState();
}

class _UjiTekanSheetState extends ConsumerState<UjiTekanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hasilCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  _QcPhase _phase = _QcPhase.input;

  @override
  void dispose() {
    _hasilCtrl.dispose();
    _targetCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  double? get _hasil =>
      double.tryParse(_hasilCtrl.text.trim().replaceAll(',', '.'));

  double? get _target {
    final text = _targetCtrl.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _submit() async {
    final targetText = _targetCtrl.text.trim().replaceAll(',', '.');
    final result = await ref
        .read(qcSubmitProvider.notifier)
        .ujiTekan(
          sessionId: widget.sessionId,
          hasilUjiTekan: double.parse(_hasilCtrl.text.replaceAll(',', '.')),
          targetMpa: targetText.isEmpty ? null : double.parse(targetText),
          catatan: _catatanCtrl.text.trim(),
        );

    AnalyticsService.qcUjitekanSubmit();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (result.delivered || result.queued) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.delivered ? 'Hasil uji tekan dicatat.' : kCopyQueued,
          ),
        ),
      );
    } else if (result.error != null) {
      // Termasuk kasus 422 "tidak ada sample slump test yang menunggu
      // hasil untuk sesi ini".
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(
            '${result.error}\n'
            'Pastikan slump test sesi ini sudah dicatat terlebih dahulu.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(qcSubmitProvider).busy;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catat Uji Tekan',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.context.produkNama ?? 'Produk'} — '
                '${widget.context.mesinNama ?? 'Mesin'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _ContextCard(context: widget.context, icon: Icons.speed),
              const SizedBox(height: 12),
              if (_phase == _QcPhase.input) ...[
                TextFormField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Target MPa (jika tersedia)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => validateNilaiOpsional(v ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hasilCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Hasil uji tekan (Actual) *',
                    suffixText: 'MPa',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => validateNilaiWajib(v ?? ''),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _catatanCtrl,
                  maxLines: 2,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Catatan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                _ResultNote(
                  text: qcResultNote(target: _target, actual: _hasil),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _phase = _QcPhase.review);
                      }
                    },
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Lanjut ke Review'),
                  ),
                ),
              ] else ...[
                _buildReview(context),
                const SizedBox(height: 12),
                _ResultNote(
                  icon: Icons.fact_check_outlined,
                  text: qcResultNote(target: _target, actual: _hasil),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy
                            ? null
                            : () => setState(() => _phase = _QcPhase.input),
                        child: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: Text(busy ? 'Menyimpan...' : 'Simpan Hasil'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final colors = context.colors;
    final targetText = _targetCtrl.text.trim().replaceAll(',', '.');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _ReviewRow(label: 'Sample', value: 'Uji Tekan (slump tercatat)'),
          _ReviewRow(
            label: 'Target MPa',
            value: targetText.isEmpty ? '-' : '$_target MPa',
          ),
          _ReviewRow(
            label: 'Actual (MPa)',
            value: '${_fmt(_hasil)} MPa',
          ),
          _ReviewRow(
            label: 'Catatan',
            value: _catatanCtrl.text.trim().isEmpty
                ? '-'
                : _catatanCtrl.text.trim(),
          ),
        ],
      ),
    );
  }
}

String _fmt(double? n) => n == null
    ? '-'
    : n % 1 == 0
    ? n.toInt().toString()
    : n.toStringAsFixed(1);
