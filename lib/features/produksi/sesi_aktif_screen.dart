import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'models/master.dart';
import 'models/production_session.dart';
import 'produksi_providers.dart';

/// Daftar sesi berstatus `berjalan` milik user + pintu ke Mulai/Riwayat/
/// Progress (Fase A2.3).
class SesiAktifScreen extends ConsumerWidget {
  const SesiAktifScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesi = ref.watch(sesiAktifProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Produksi'),
        actions: [
          IconButton(
            tooltip: 'Progress hari ini',
            icon: const Icon(Icons.insights),
            onPressed: () => context.push('/produksi/progress'),
          ),
          IconButton(
            tooltip: 'Riwayat',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/produksi/riwayat'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/produksi/mulai'),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai Sesi'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(sesiAktifProvider.future),
        child: sesi.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: e is ApiException ? e.message : 'Gagal memuat sesi aktif.',
            onRetry: () => ref.invalidate(sesiAktifProvider),
          ),
          data: (items) => items.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 160),
                    Icon(Icons.factory_outlined, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Tidak ada sesi berjalan.\nTekan "Mulai Sesi" untuk memulai.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _SessionCard(session: items[i]),
                ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final ProductionSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mulai = session.mulai?.toLocal();
    final durasi = mulai == null ? null : DateTime.now().difference(mulai);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${session.produkNama ?? 'Produk'} — ${session.mesinNama ?? 'Mesin'}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Chip(
                  label: const Text('Berjalan'),
                  backgroundColor:
                      theme.colorScheme.primaryContainer.withValues(alpha: .5),
                  labelStyle: TextStyle(
                      fontSize: 11, color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Titik: ${session.titikNama ?? '-'}'),
            if (mulai != null)
              Text(
                'Mulai ${_fmtJam(mulai)}'
                '${durasi != null ? ' • ${durasi.inHours}j ${durasi.inMinutes % 60}m' : ''}',
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text('Selesaikan'),
                onPressed: () => _openSelesaikan(context, session),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSelesaikan(BuildContext context, ProductionSession session) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SelesaikanSheet(session: session),
    );
  }
}

String _fmtJam(DateTime t) =>
    '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Icon(Icons.cloud_off, size: 44, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi'))),
      ],
    );
  }
}

/// Form penutupan sesi: hasil_output wajib, catatan opsional, dan
/// konsumsi bahan baku manual (items[]) — kosong = hitung otomatis BOM.
class _SelesaikanSheet extends ConsumerStatefulWidget {
  const _SelesaikanSheet({required this.session});

  final ProductionSession session;

  @override
  ConsumerState<_SelesaikanSheet> createState() => _SelesaikanSheetState();
}

class _SelesaikanSheetState extends ConsumerState<_SelesaikanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hasilCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  final List<_ItemRow> _rows = [];

  String get _satuan => widget.session.satuanOutput ?? '';

  @override
  void dispose() {
    _hasilCtrl.dispose();
    _catatanCtrl.dispose();
    for (final r in _rows) {
      r.jumlahCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final items = <({String bahanBakuId, double jumlahTerpakai})>[];
    for (final row in _rows) {
      if (row.bahan == null) continue;
      final jumlah = double.tryParse(row.jumlahCtrl.text.replaceAll(',', '.'));
      if (jumlah == null || jumlah < 0) continue;
      items.add((bahanBakuId: row.bahan!.id, jumlahTerpakai: jumlah));
    }

    final result =
        await ref.read(produksiSubmitProvider.notifier).selesai(
              sessionId: widget.session.id,
              hasilOutput: double.parse(_hasilCtrl.text.replaceAll(',', '.')),
              catatan: _catatanCtrl.text.trim(),
              items: items,
            );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (result.delivered) {
      messenger.showSnackBar(const SnackBar(content: Text('Sesi produksi selesai.')));
    } else if (result.queued) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Offline — penutupan sesi masuk antrean kirim otomatis.'),
      ));
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(produksiSubmitProvider).busy;
    final bahanAsync = ref.watch(bahanBakuProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selesaikan Sesi',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('${widget.session.produkNama ?? ''} • ${widget.session.mesinNama ?? ''}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hasilCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Hasil output *',
                  suffixText: _satuan.isEmpty ? null : _satuan,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null) return 'Masukkan angka yang valid.';
                  if (n < 0) return 'Tidak boleh negatif.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _catatanCtrl,
                maxLines: 2,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              _ItemsOverrideSection(rows: _rows, bahanAsync: bahanAsync),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : _submit,
                  child: Text(busy ? 'Menyimpan...' : 'Selesaikan Sesi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow {
  _ItemRow();

  BahanBakuMaster? bahan;
  final jumlahCtrl = TextEditingController();
}

class _ItemsOverrideSection extends StatelessWidget {
  const _ItemsOverrideSection({required this.rows, required this.bahanAsync});

  final List<_ItemRow> rows;
  final AsyncValue<List<BahanBakuMaster>> bahanAsync;

  @override
  Widget build(BuildContext context) {
    final bahanList = bahanAsync.value ?? const <BahanBakuMaster>[];

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Konsumsi bahan baku manual (opsional)'),
      subtitle: const Text('Kosongkan agar dihitung otomatis dari resep (BOM)'),
      children: [
        StatefulBuilder(
          builder: (context, setSheetState) => Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<BahanBakuMaster>(
                        initialValue: rows[i].bahan,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Bahan baku'),
                        items: [
                          for (final b in bahanList)
                            DropdownMenuItem(value: b, child: Text(b.nama)),
                        ],
                        onChanged: (v) => setSheetState(() => rows[i].bahan = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: rows[i].jumlahCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Jumlah',
                          suffixText: rows[i].bahan?.satuan,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus baris',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () =>
                          setSheetState(() => rows.removeAt(i)),
                    ),
                  ],
                ),
              TextButton.icon(
                onPressed: bahanList.isEmpty
                    ? null
                    : () => setSheetState(() => rows.add(_ItemRow())),
                icon: const Icon(Icons.add),
                label: const Text('Tambah bahan'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
