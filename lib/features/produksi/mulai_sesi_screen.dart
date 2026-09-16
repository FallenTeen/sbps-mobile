import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/adaptive_form_row.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/api_client.dart';
import '../presensi/models/titik.dart';
import '../presensi/presensi_providers.dart';
import '../titik/titik_selector.dart';
import 'models/master.dart';
import 'produksi_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Halaman "Mulai Sesi" (Fase A2.3): pilih mesin & produk dari master;
/// titik_id default ke titik mesin bila tidak diisi (backend menangani).
class MulaiSesiScreen extends ConsumerStatefulWidget {
  const MulaiSesiScreen({super.key});

  @override
  ConsumerState<MulaiSesiScreen> createState() => _MulaiSesiScreenState();
}

class _MulaiSesiScreenState extends ConsumerState<MulaiSesiScreen> {
  final _catatanCtrl = TextEditingController();

  MesinMaster? _mesin;
  ProdukMaster? _produk;
  Titik? _titik;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  void _onMesinChanged(MesinMaster? mesin, List<ProdukMaster> produkList) {
    setState(() {
      _mesin = mesin;
      // Prefill produk default milik mesin bila ada di daftar produk.
      ProdukMaster? prefill;
      if (mesin?.produkDefaultId != null) {
        for (final p in produkList) {
          if (p.id == mesin!.produkDefaultId) {
            prefill = p;
            break;
          }
        }
      }
      _produk = prefill ?? _produk;
    });
  }

  Future<void> _submit() async {
    if (_mesin == null || _produk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih mesin dan produk terlebih dahulu.'),
        ),
      );
      return;
    }

    final result = await ref
        .read(produksiSubmitProvider.notifier)
        .mulai(
          mesinId: _mesin!.id,
          produkId: _produk!.id,
          titikId: _titik?.id,
          catatan: _catatanCtrl.text.trim(),
        );

    AnalyticsService.produksiSesiMulai();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.delivered || result.queued) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.delivered
                ? 'Sesi produksi dimulai.'
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
    final busy = ref.watch(produksiSubmitProvider).busy;
    final mesinAsync = ref.watch(mesinProvider);
    final produkAsync = ref.watch(produkProvider);
    final titikAsync = ref.watch(titikAktifProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mulai Sesi Produksi'),
        actions: const [PortalSwitchButton()],
      ),
      body: ResponsiveCenter(
        child: mesinAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonDetailView(),
          ),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e is ApiException ? e.message : 'Gagal memuat master data.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(mesinProvider),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
          data: (mesinList) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AdaptiveFormRow(
                spacing: 16,
                fields: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<MesinMaster>(
                        initialValue: _mesin,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Mesin *',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final m in mesinList)
                            DropdownMenuItem(value: m, child: Text(m.nama)),
                        ],
                        onChanged: (v) =>
                            _onMesinChanged(v, produkAsync.value ?? const []),
                      ),
                      if (_mesin?.titikNama != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'Titik mesin: ${_mesin!.titikNama}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                  DropdownButtonFormField<ProdukMaster>(
                    // Key agar field dibuat ulang saat produk di-prefill
                    // otomatis dari produk default mesin.
                    key: ValueKey(_produk?.id ?? 'produk-none'),
                    initialValue: _produk,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Produk *',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p
                          in produkAsync.value ?? const <ProdukMaster>[])
                        DropdownMenuItem(value: p, child: Text(p.nama)),
                    ],
                    onChanged: (v) => setState(() => _produk = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Titik kerja (opsional, override titik mesin).
              if (titikAsync.value != null && titikAsync.value!.isNotEmpty) ...[
                TitikSelector(
                  titikList: titikAsync.value!,
                  selectedTitik: _titik,
                  mapHeight: 220,
                  onChanged: (t) => setState(() => _titik = t),
                  listBuilder: (context, _) => DropdownButtonFormField<Titik?>(
                    initialValue: _titik,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Titik Kerja (opsional)',
                      border: OutlineInputBorder(),
                      helperText:
                          'Kosongkan untuk otomatis mengikuti titik mesin',
                    ),
                    items: [
                      const DropdownMenuItem<Titik?>(
                        value: null,
                        child: Text('Otomatis (ikuti titik mesin)'),
                      ),
                      for (final t in titikAsync.value!)
                        DropdownMenuItem<Titik?>(value: t, child: Text(t.nama)),
                    ],
                    onChanged: (v) => setState(() => _titik = v),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _catatanCtrl,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              BouncingButton(
                onPressed: busy ? null : _submit,
                child: FilledButton.icon(
                  onPressed: busy ? null : _submit,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(busy ? 'Memulai...' : 'Mulai Sesi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
