import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'models/master.dart';
import 'produksi_providers.dart';

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
        const SnackBar(content: Text('Pilih mesin dan produk terlebih dahulu.')),
      );
      return;
    }

    final result = await ref.read(produksiSubmitProvider.notifier).mulai(
          mesinId: _mesin!.id,
          produkId: _produk!.id,
          catatan: _catatanCtrl.text.trim(),
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.delivered || result.queued) {
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        content: Text(result.delivered
            ? 'Sesi produksi dimulai.'
            : 'Offline — sesi masuk antrean, dikirim otomatis saat online.'),
      ));
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(produksiSubmitProvider).busy;
    final mesinAsync = ref.watch(mesinProvider);
    final produkAsync = ref.watch(produkProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mulai Sesi Produksi')),
      body: mesinAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is ApiException ? e.message : 'Gagal memuat master data.'),
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
            const SizedBox(height: 16),
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
                for (final p in produkAsync.value ?? const <ProdukMaster>[])
                  DropdownMenuItem(value: p, child: Text(p.nama)),
              ],
              onChanged: (v) => setState(() => _produk = v),
            ),
            const SizedBox(height: 16),
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
            FilledButton.icon(
              onPressed: busy ? null : _submit,
              icon: const Icon(Icons.play_arrow),
              label: Text(busy ? 'Memulai...' : 'Mulai Sesi'),
            ),
          ],
        ),
      ),
    );
  }
}
