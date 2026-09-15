import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../qc/qc_providers.dart';
import '../qc/qc_sheets.dart';
import '../qc/models/qc_sample.dart';
import 'models/master.dart';
import 'models/production_session.dart';
import 'produksi_providers.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'produksi_ringkasan_screen.dart';

/// Daftar sesi berstatus `berjalan` milik user + pintu ke Mulai/Riwayat/
/// Progress (Fase A2.3) - Refactored with TabBar (Fase 2).
class SesiAktifScreen extends ConsumerStatefulWidget {
  const SesiAktifScreen({super.key});

  @override
  ConsumerState<SesiAktifScreen> createState() => _SesiAktifScreenState();
}

class _SesiAktifScreenState extends ConsumerState<SesiAktifScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesi = ref.watch(sesiAktifProvider);
    // Peta sessionId → sample menunggu_hasil: penentu tombol QC per kartu.
    final waitingQc = ref.watch(waitingSamplesBySessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Produksi'),
        actions: [
          const PortalSwitchButton(),
          // Context menu for additional actions (Fase 2)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'ringkasan':
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProduksiRingkasanScreen(),
                    ),
                  );
                  break;
                case 'dokumentasi':
                  context.push('/dokumentasi');
                  break;
                case 'qc':
                  context.push('/qc/riwayat');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'ringkasan',
                child: Row(
                  children: [
                    Icon(Icons.dashboard_outlined),
                    SizedBox(width: 12),
                    Text('Ringkasan Produksi'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'dokumentasi',
                child: Row(
                  children: [
                    Icon(Icons.attach_file),
                    SizedBox(width: 12),
                    Text('Dokumentasi'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'qc',
                child: Row(
                  children: [
                    Icon(Icons.science_outlined),
                    SizedBox(width: 12),
                    Text('Riwayat QC'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Sesi Aktif'),
            Tab(text: 'Progress'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/produksi/mulai'),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Mulai Sesi'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Sesi Aktif
          _ActiveSessionsTab(sesi: sesi, waitingQc: waitingQc),
          // Tab 2: Progress (redirect to progress screen)
          const _ProgressTab(),
          // Tab 3: Riwayat (redirect to history screen)
          const _HistoryTab(),
        ],
      ),
    );
  }
}

class _ActiveSessionsTab extends ConsumerWidget {
  const _ActiveSessionsTab({required this.sesi, required this.waitingQc});

  final AsyncValue<List<ProductionSession>> sesi;
  final AsyncValue<Map<String, QcSample>> waitingQc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sesiAktifProvider),
      child: sesi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e is ApiException ? e.message : 'Gagal memuat sesi aktif.',
          onRetry: () => ref.invalidate(sesiAktifProvider),
        ),
        data: (items) => CustomScrollView(
          slivers: [
            // Summary header (Fase 2)
            if (items.isNotEmpty)
              SliverToBoxAdapter(
                child: _SessionSummaryHeader(
                  activeCount: items.length,
                  waitingQcCount: waitingQc.value?.length ?? 0,
                ),
              ),
            // Session list
            items.isEmpty
                ? SliverFillRemaining(
                    child: const AppEmptyState(
                      icon: Icons.factory_outlined,
                      title: 'Belum ada sesi aktif',
                      subtitle:
                          'Mulai sesi produksi baru dengan menekan tombol + di bawah.',
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          SliverToBoxAdapter(child: SizedBox(height: 12)),
                      itemBuilder: (context, i) => _SessionCard(
                        session: items[i],
                        hasWaitingQc:
                            waitingQc.value?.containsKey(items[i].id) ?? false,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummaryHeader extends StatelessWidget {
  const _SessionSummaryHeader({
    required this.activeCount,
    required this.waitingQcCount,
  });

  final int activeCount;
  final int waitingQcCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Sesi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$activeCount sesi aktif',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (waitingQcCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$waitingQcCount QC tertunda',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

class _ProgressTab extends StatelessWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: context.colors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Progress Hari Ini',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Lihat progress produksi hari ini',
            style: TextStyle(color: context.colors.textTertiary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/produksi/progress'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Buka Halaman Progress'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: context.colors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Riwayat Produksi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Lihat riwayat sesi produksi',
            style: TextStyle(color: context.colors.textTertiary),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/produksi/riwayat'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Buka Halaman Riwayat'),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.hasWaitingQc});

  final ProductionSession session;

  /// true bila sesi ini sudah punya sample slump menunggu hasil uji tekan.
  final bool hasWaitingQc;

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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Chip(
                  label: const Text('Berjalan'),
                  backgroundColor: theme.colorScheme.primaryContainer
                      .withValues(alpha: .5),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Titik: ${session.titikNama ?? '-'}'),
            if (mulai != null)
              Text(
                'Mulai ${fmtTanggalWaktu(mulai)}'
                '${durasi != null ? ' • ${durasi.inHours}j ${durasi.inMinutes % 60}m' : ''}',
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: hasWaitingQc
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.speed, size: 18),
                          label: const Text('Catat Uji Tekan'),
                          onPressed: () => _openUjiTekan(context),
                        )
                      : TextButton.icon(
                          icon: const Icon(Icons.science_outlined, size: 18),
                          label: const Text('Catat Slump Test'),
                          onPressed: () => _openSlumpTest(context),
                        ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('Selesaikan'),
                  onPressed: () => _openSelesaikan(context, session),
                ),
              ],
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

  void _openSlumpTest(BuildContext context) {
    final judul =
        '${session.produkNama ?? 'Produk'} — ${session.mesinNama ?? 'Mesin'}';
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SlumpTestSheet(sessionId: session.id, judul: judul),
    );
  }

  void _openUjiTekan(BuildContext context) {
    final judul =
        '${session.produkNama ?? 'Produk'} — ${session.mesinNama ?? 'Mesin'}';
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UjiTekanSheet(sessionId: session.id, judul: judul),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Icon(
          Icons.cloud_off,
          size: 44,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ),
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

    final result = await ref
        .read(produksiSubmitProvider.notifier)
        .selesai(
          sessionId: widget.session.id,
          hasilOutput: double.parse(_hasilCtrl.text.replaceAll(',', '.')),
          catatan: _catatanCtrl.text.trim(),
          items: items,
        );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (result.delivered) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sesi produksi selesai.')),
      );
    } else if (result.queued) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tersimpan offline — akan dikirim otomatis saat online. Gunakan tombol ☁️ di atas untuk sinkron manual.',
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
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.session.produkNama ?? ''} • ${widget.session.mesinNama ?? ''}',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hasilCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                        decoration: const InputDecoration(
                          labelText: 'Bahan baku',
                        ),
                        items: [
                          for (final b in bahanList)
                            DropdownMenuItem(value: b, child: Text(b.nama)),
                        ],
                        onChanged: (v) =>
                            setSheetState(() => rows[i].bahan = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: rows[i].jumlahCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Jumlah',
                          suffixText: rows[i].bahan?.satuan,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus baris',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setSheetState(() => rows.removeAt(i)),
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
