import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/submit_spinner.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import '../armada/models/armada.dart';
import 'security_repository.dart';

/// Layar Verifikasi Keamanan Ritase oleh Security (Section 27, TD-E4 & TD-F5).
class SecurityVerifikasiRitaseScreen extends ConsumerStatefulWidget {
  const SecurityVerifikasiRitaseScreen({super.key});

  @override
  ConsumerState<SecurityVerifikasiRitaseScreen> createState() =>
      _SecurityVerifikasiRitaseScreenState();
}

class _SecurityVerifikasiRitaseScreenState
    extends ConsumerState<SecurityVerifikasiRitaseScreen> {
  Future<void> _openVerifikasiModal(RitaseItem ritase) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SecurityVerifikasiFormSheet(ritase: ritase),
    );

    if (result == true && mounted) {
      ref.invalidate(ritaseSecurityAntreanProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ritaseAsync = ref.watch(ritaseSecurityAntreanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verifikasi Keamanan Ritase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(ritaseSecurityAntreanProvider),
          ),
        ],
      ),
      body: ritaseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: context.colors.error),
                const SizedBox(height: 12),
                Text(
                  friendlyErrorMessage(
                    err,
                    fallback: 'Gagal memuat ritase security. Coba lagi.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(ritaseSecurityAntreanProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(ritaseSecurityAntreanProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  AppEmptyState(
                    icon: Icons.shield_outlined,
                    title: 'Tidak Ada Ritase Siap Cek',
                    subtitle: 'Belum ada ritase terverifikasi logistik yang memerlukan pemeriksaan security.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ritaseSecurityAntreanProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final item = items[i];
                final isSecVerified = item.isVerifiedSecurity;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSecVerified ? context.colors.success.withValues(alpha: 0.4) : context.colors.border,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.armadaPlat ?? 'Unit Kendaraan',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sopir: ${item.driverNama ?? 'Driver'} • ${fmtTanggal(item.tanggal)}',
                                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (isSecVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.colors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colors.success.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Verified (Security)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.success),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.colors.info.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.colors.info.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Verified (Logistik)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.info),
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Material: ${item.material ?? 'Muatan'}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            if (item.jumlahVerifikasiLogistik != null)
                              Text(
                                'Netto Logistik: ${item.jumlahVerifikasiLogistik} ton',
                                style: TextStyle(fontSize: 12, color: context.colors.info, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        if (item.ruteAsal != null || item.ruteTujuan != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${item.ruteAsal ?? '-'} → ${item.ruteTujuan ?? '-'}',
                            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: BouncingButton(
                            onPressed: () => _openVerifikasiModal(item),
                            child: OutlinedButton.icon(
                              onPressed: () => _openVerifikasiModal(item),
                              icon: const Icon(Icons.shield_outlined, size: 18),
                              label: Text(isSecVerified ? 'Pemeriksaan Selesai (Edit)' : 'Konfirmasi Keamanan Unit'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SecurityVerifikasiFormSheet extends ConsumerStatefulWidget {
  const _SecurityVerifikasiFormSheet({required this.ritase});

  final RitaseItem ritase;

  @override
  ConsumerState<_SecurityVerifikasiFormSheet> createState() =>
      _SecurityVerifikasiFormSheetState();
}

class _SecurityVerifikasiFormSheetState
    extends ConsumerState<_SecurityVerifikasiFormSheet> {
  bool _unitSesuai = true;
  bool _muatanAman = true;
  String? _fotoPath;
  final _catatanCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _takeFoto() async {
    final captured = await takeWatermarkedPhoto(ref);
    if (captured != null && mounted) {
      setState(() => _fotoPath = captured.path);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(securityRepositoryProvider);
      await repo.submitVerifikasiRitaseSecurity(
        ritaseId: widget.ritase.id,
        unitSesuai: _unitSesuai,
        muatanAman: _muatanAman,
        fotoPath: _fotoPath,
        catatan: _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
      );

      AnalyticsService.log('security_verifikasi_ritase_submit', {
        'ritase_id': widget.ritase.id,
        'unit_sesuai': _unitSesuai,
        'muatan_aman': _muatanAman,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verifikasi keamanan ritase berhasil disimpan.'),
          backgroundColor: context.colors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal menyimpan. Coba lagi.'),
          ),
          backgroundColor: context.colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: context.colors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pemeriksaan Unit: ${widget.ritase.armadaPlat ?? '-'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),

            CheckboxListTile(
              value: _unitSesuai,
              onChanged: (v) => setState(() => _unitSesuai = v ?? false),
              title: const Text('Fisik unit kendaraan & nomor plat sesuai data armada'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            CheckboxListTile(
              value: _muatanAman,
              onChanged: (v) => setState(() => _muatanAman = v ?? false),
              title: const Text('Kondisi muatan aman, terpal tertutup rapi & tidak tumpah'),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            const SizedBox(height: 12),

            if (_fotoPath != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_fotoPath!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                    onPressed: () => setState(() => _fotoPath = null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else
              OutlinedButton.icon(
                onPressed: _takeFoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Ambil Foto Armada / Muatan (Opsional)'),
              ),
            const SizedBox(height: 12),

            TextField(
              controller: _catatanCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan Security (opsional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: BouncingButton(
                onPressed: _isSubmitting ? () {} : _submit,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.success,
                  ),
                  icon: _isSubmitting
                      ? const SubmitSpinner(size: 18)
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isSubmitting ? 'Menyimpan...' : 'Konfirmasi Verified Security'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
