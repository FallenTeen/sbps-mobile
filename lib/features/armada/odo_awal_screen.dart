import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/armada_jenis.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/submit_spinner.dart';
import 'armada_providers.dart';
import 'checklist_model.dart';
import 'models/armada.dart';

/// ODO/HM Harian — input sekali per hari (KM untuk kendaraan, HM/jam untuk
/// alat berat). Source of truth ODO/HM adalah `GET /armada/saya` → [ArmadaSaya]
/// yang juga dipakai Home, Checklist, dan Ritase (odo_per_trip).
///
/// Menampilkan: tipe unit + satuan, terakhir (previous), sekarang (current),
/// pemakaian (delta), serta warning ANOMALI bila nilai sekarang lebih kecil
/// dari yang tercatat — nilai tidak diterima secara diam-diam, business rule
/// backend tidak diubah.
class OdoAwalScreen extends ConsumerStatefulWidget {
  const OdoAwalScreen({super.key});

  @override
  ConsumerState<OdoAwalScreen> createState() => _OdoAwalScreenState();
}

class _OdoAwalScreenState extends ConsumerState<OdoAwalScreen> {
  ArmadaSaya? _selectedArmada;
  late final TextEditingController _odoController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _odoController = TextEditingController();
  }

  @override
  void dispose() {
    _odoController.dispose();
    super.dispose();
  }

  double? get _previousValue {
    final a = _selectedArmada;
    if (a == null) return null;
    return a.isAlatBerat ? a.jamOperasionalTerkini : a.odoTerkini;
  }

  double? get _currentParsed => double.tryParse(_odoController.text.trim());

  /// Satuan yang dipakai unit ini: KM untuk kendaraan, HM (jam) untuk alat.
  String get _satuan => _selectedArmada == null
      ? 'KM'
      : _selectedArmada!.isAlatBerat
      ? 'HM'
      : 'KM';

  void _applyArmada(ArmadaSaya armada) {
    setState(() {
      _selectedArmada = armada;
      final last = armada.isAlatBerat
          ? armada.jamOperasionalTerkini
          : armada.odoTerkini;
      // Prefill: sistem sudah tahu unit & nilai terakhir → isi otomatis.
      if (last != null && _odoController.text.trim().isEmpty) {
        _odoController.text = last % 1 == 0
            ? last.toInt().toString()
            : last.toStringAsFixed(1);
      } else if (last == null && _odoController.text.trim().isEmpty) {
        _odoController.clear();
      }
    });
  }

  Future<void> _confirmAnomaly() async {
    final last = _previousValue;
    final cur = _currentParsed;
    if (last == null || cur == null || cur >= last) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bacaan Lebih Kecil'),
        content: Text(
          'Nilai yang diisi (${fmtOdo(cur)}) LEBIH KECIL dari terakhir '
          'tercatat (${fmtOdo(last)}).\n\n'
          'Pastikan bacaan sudah benar sebelum melanjutkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Periksa Lagi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.warning,
            ),
            child: const Text('Lanjut Simpan'),
          ),
        ],
      ),
    );
    if (ok == true) _submit();
  }

  Future<void> _submit() async {
    final armada = _selectedArmada;
    if (armada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kendaraan terlebih dahulu')),
      );
      return;
    }
    if (_odoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            armada.isAlatBerat
                ? 'Jam Kerja Unit harus diisi'
                : 'KM harus diisi',
          ),
        ),
      );
      return;
    }

    final odoValue = double.tryParse(_odoController.text.trim());
    if (odoValue == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Format angka tidak valid')));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      bool delivered = false;
      String? permanentError;
      final titikId =
          (armada.titikId != null && armada.titikId!.trim().isNotEmpty)
          ? armada.titikId!.trim()
          : null;

      // 1. Simpan ODO/HM ke checklist harian agar langsung tercermin di unit saya.
      // Pertahankan kondisi_baik & item_bermasalah yang sudah tercatat sebelumnya.
      final existingChecklist = ref
          .read(checklistHariIniProvider)
          .value
          ?.where((c) => c.armadaId == armada.id)
          .firstOrNull;
      final kondisiBaik = existingChecklist?.kondisiBaik ?? true;
      final itemBermasalah = existingChecklist?.itemBermasalah;

      try {
        delivered = await ref
            .read(armadaRepositoryProvider)
            .submitChecklist(
              armadaId: armada.id,
              kondisiBaik: kondisiBaik,
              itemBermasalah: itemBermasalah,
              odoKm: armada.isAlatBerat ? null : odoValue,
              jamOperasional: armada.isAlatBerat ? odoValue : null,
            );
      } on ApiException catch (e) {
        // 4xx permanen: jangan telan — permukaan ke user (queued ≠ gagal).
        permanentError = e.message;
      } catch (_) {}

      // 2. Simpan ODO awal proyek bila belum pernah tercatat
      try {
        final odoAwalDelivered = await ref
            .read(armadaRepositoryProvider)
            .submitOdoAwalProyek(
              armadaId: armada.id,
              titikId: titikId,
              odoAwal: odoValue,
            );
        delivered = delivered || odoAwalDelivered;
      } on ApiException catch (e) {
        // 422 = sudah pernah tercatat (efektif sukses) — abaikan. Error lain
        // (403/404/400) tetap permukaan bila tidak ada yang berhasil.
        if (e.statusCode != 422) permanentError ??= e.message;
      } catch (_) {}

      ref.invalidate(armadaSayaProvider);
      ref.invalidate(checklistHariIniProvider);

      if (!mounted) return;
      HapticFeedback.lightImpact();
      AnalyticsService.odoSave();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? (armada.isAlatBerat
                      ? 'Jam Kerja Unit berhasil diperbarui'
                      : 'KM terkini berhasil diperbarui')
                : (permanentError ?? kCopyQueued),
          ),
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/armada/unit-saya');
      }
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
            friendlyErrorMessage(e, fallback: 'Gagal menyimpan. Coba lagi.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSubmitPressed() {
    final reading = OdoReading(
      previous: _previousValue,
      current: _currentParsed,
    );
    if (reading.decreased) {
      _confirmAnomaly();
    } else {
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ODO / HM Harian'),
        actions: [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat data armada',
          subtitle:
              'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(armadaSayaProvider),
        ),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const AppEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Tidak ada armada yang ditugaskan',
              subtitle:
                  'Hubungi admin untuk mendapatkan penugasan unit kendaraan.',
            );
          }

          final onlyOne = armadaList.length == 1;
          if (onlyOne && _selectedArmada?.id != armadaList.first.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedArmada?.id != armadaList.first.id) {
                _applyArmada(armadaList.first);
              }
            });
          }
          final armada = onlyOne ? armadaList.first : _selectedArmada;
          if (armada == null) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _unitDropdown(armadaList),
                const SizedBox(height: 16),
                Text(
                  'Pilih unit untuk melihat ODO/HM terakhir dan nilai sekarang.',
                  style: TextStyle(
                    color: context.colors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ],
            );
          }

          final last = armada.isAlatBerat
              ? armada.jamOperasionalTerkini
              : armada.odoTerkini;
          final reading = OdoReading(previous: last, current: _currentParsed);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _unitDropdown(armadaList),
              const SizedBox(height: 16),

              // Tipe unit + satuan (kendaraan → KM, alat berat → HM/jam).
              _UnitTypeBanner(isAlatBerat: armada.isAlatBerat),

              const SizedBox(height: 16),

              // Terakhir / sekarang / pemakaian (delta).
              _ReadingCard(
                isAlatBerat: armada.isAlatBerat,
                last: last,
                current: _odoController.text,
                reading: reading,
              ),

              const SizedBox(height: 16),

              // Warning anomali: nilai turun tidak diterima diam-diam.
              if (reading.decreased) ...[
                _AnomalyWarning(
                  last: last!,
                  current: reading.current!,
                  isAlatBerat: armada.isAlatBerat,
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _odoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: armada.isAlatBerat
                      ? 'Jam Kerja Unit Sekarang (HM)'
                      : 'KM Sekarang (Odometer)',
                  suffixText: _satuan,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    armada.isAlatBerat
                        ? Icons.timer_outlined
                        : Icons.speed_outlined,
                  ),
                  helperText: armada.isAlatBerat
                      ? 'Total jam mesin menyala dari Hour Meter'
                      : 'Angka pada odometer (penghitung km) kendaraan',
                ),
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: BouncingButton(
                  onPressed: _isLoading ? null : _onSubmitPressed,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _onSubmitPressed,
                    icon: _isLoading
                        ? const SubmitSpinner()
                        : const Icon(Icons.save),
                    label: Text(
                      _isLoading
                          ? 'Menyimpan...'
                          : armada.isAlatBerat
                          ? 'Simpan Jam Kerja Unit'
                          : 'Simpan KM',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _unitDropdown(List<ArmadaSaya> armadaList) {
    return DropdownButtonFormField<ArmadaSaya>(
      initialValue: _selectedArmada,
      decoration: InputDecoration(
        labelText: armadaList.length == 1 ? 'Unit ' : 'Pilih Kendaraan',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.local_shipping_outlined),
        helperText: armadaList.length == 1
            ? '${_labelJenis(_selectedArmada?.jenis)} • titik '
                  '${_selectedArmada?.titikNama ?? '-'}'
            : 'Pilih unit yang akan Anda operasikan hari ini',
      ),
      items: armadaList
          .map(
            (a) => DropdownMenuItem(
              value: a,
              child: Text('${a.platNomor} — ${a.jenis ?? a.kodeUnit ?? ""}'),
            ),
          )
          .toList(),
      onChanged: armadaList.length == 1
          ? null
          : (v) {
              if (v != null) _applyArmada(v);
            },
    );
  }
}

String _labelJenis(String? jenis) => labelJenisArmada(jenis, fallback: 'Unit');

/// Format ODO/HM (bulat bila bulat, ribuan bertitik).
String fmtOdo(double n) => fmtRibuan(n % 1 == 0 ? n.toInt() : n.round());

class _UnitTypeBanner extends StatelessWidget {
  const _UnitTypeBanner({required this.isAlatBerat});

  final bool isAlatBerat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAlatBerat ? Icons.construction : Icons.speed_outlined,
            color: context.colors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAlatBerat
                  ? 'Alat Berat — nilai dalam HM (jam mesin)'
                  : 'Kendaraan — nilai dalam KM (odometer)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.isAlatBerat,
    required this.last,
    required this.current,
    required this.reading,
  });

  final bool isAlatBerat;
  final double? last;
  final String current;
  final OdoReading reading;

  @override
  Widget build(BuildContext context) {
    final label = isAlatBerat ? 'HM Terakhir' : 'ODO Terakhir';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
              ),
              Text(
                last == null ? 'Belum tercatat' : fmtOdo(last!),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAlatBerat ? 'Sekarang (HM)' : 'Sekarang (KM)',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
              ),
              Text(
                reading.current == null ? '-' : fmtOdo(reading.current!),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pemakaian',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
              ),
              Text(
                reading.pemakaianLabel(isAlatBerat) ?? '-',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: reading.decreased
                      ? context.colors.warning
                      : context.colors.success,
                ),
              ),
            ],
          ),
          if (reading.pemakaianLabel(isAlatBerat) != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Δ ${isAlatBerat ? 'jam' : 'km'} = sekarang - terakhir',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnomalyWarning extends StatelessWidget {
  const _AnomalyWarning({
    required this.last,
    required this.current,
    required this.isAlatBerat,
  });

  final double last;
  final double current;
  final bool isAlatBerat;

  @override
  Widget build(BuildContext context) {
    final unit = isAlatBerat ? 'jam' : 'km';
    final warningColor = context.colors.warning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warningColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warningColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: warningColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anomali: nilai lebih kecil dari terakhir tercatat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nilai sekarang ${fmtOdo(current)} $unit LEBIH KECIL dari '
                  '${fmtOdo(last)} $unit. Periksa kembali bacaan Anda.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Anda akan diminta konfirmasi sebelum menyimpan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
