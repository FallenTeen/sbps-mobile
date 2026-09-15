import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import 'qc_providers.dart';

/// Bottom sheet "Catat Slump Test" (Fase A2.5).
class SlumpTestSheet extends ConsumerStatefulWidget {
  const SlumpTestSheet({
    super.key,
    required this.sessionId,
    required this.judul,
  });

  final String sessionId;
  final String judul;

  @override
  ConsumerState<SlumpTestSheet> createState() => _SlumpTestSheetState();
}

class _SlumpTestSheetState extends ConsumerState<SlumpTestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nilaiCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  @override
  void dispose() {
    _nilaiCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
                : 'Tersimpan offline — akan dikirim otomatis saat online. Gunakan tombol ☁️ di atas untuk sinkron manual.',
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
            Text(widget.judul),
            const SizedBox(height: 16),
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
                labelText: 'Nilai slump *',
                suffixText: 'mm',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null) return 'Masukkan angka yang valid.';
                return null;
              },
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : _submit,
                child: Text(busy ? 'Menyimpan...' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet "Catat Uji Tekan" — sesi harus punya sample slump yang
/// masih menunggu hasil.
class UjiTekanSheet extends ConsumerStatefulWidget {
  const UjiTekanSheet({
    super.key,
    required this.sessionId,
    required this.judul,
  });

  final String sessionId;
  final String judul;

  @override
  ConsumerState<UjiTekanSheet> createState() => _UjiTekanSheetState();
}

class _UjiTekanSheetState extends ConsumerState<UjiTekanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hasilCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  @override
  void dispose() {
    _hasilCtrl.dispose();
    _targetCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
            result.delivered
                ? 'Hasil uji tekan dicatat.'
                : 'Tersimpan offline — akan dikirim otomatis saat online. Gunakan tombol ☁️ di atas untuk sinkron manual.',
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
            Text(widget.judul),
            const SizedBox(height: 16),
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
                labelText: 'Hasil uji tekan *',
                suffixText: 'MPa',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null) return 'Masukkan angka yang valid.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Target MPa (opsional)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim().replaceAll(',', '.');
                if (t.isEmpty) return null;
                if (double.tryParse(t) == null) {
                  return 'Angka tidak valid.';
                }
                return null;
              },
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : _submit,
                child: Text(busy ? 'Menyimpan...' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
