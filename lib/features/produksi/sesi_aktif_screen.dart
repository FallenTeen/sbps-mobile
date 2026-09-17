import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/status_pill.dart';
import '../qc/qc_providers.dart';
import '../qc/qc_sheets.dart';
import '../qc/models/qc_sample.dart';
import 'models/master.dart';
import 'models/production_session.dart';
import 'produksi_providers.dart';
import 'produksi_rules.dart';
import 'produksi_ringkasan_screen.dart';
import 'progress_hari_ini_screen.dart';
import 'riwayat_produksi_screen.dart';

/// Daftar sesi berstatus `berjalan` milik user + pintu ke Mulai/Riwayat/
/// Progress. Phase 13: setiap tab memiliki konten nyata (tidak ada tab yang
/// hanya mengantar ke halaman lain), home menampilkan ringkasan
/// "Produksi Hari Ini", dan kartu sesi menampilkan next action.
class SesiAktifScreen extends ConsumerStatefulWidget {
  const SesiAktifScreen({super.key});

  @override
  ConsumerState<SesiAktifScreen> createState() => _SesiAktifScreenState();
}

class _SesiAktifScreenState extends ConsumerState<SesiAktifScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _durationTicker;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Durasi sesi berjalan diperbarui tiap menit.
    _durationTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _tabController.index == 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _durationTicker?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesi = ref.watch(sesiAktifProvider);
    // Peta sessionId → sample menunggu_hasil: penentu tombol QC per kartu.
    final waitingQc = ref.watch(waitingSamplesBySessionProvider);
    // Progress per titik hari ini — dasar ringkasan "Produksi Hari Ini".
    final progress = ref.watch(titikProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Produksi'),
        actions: [
          const PortalSwitchButton(),
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
          // Tab 1: Sesi Aktif + ringkasan Produksi Hari Ini.
          _ActiveSessionsTab(
            sesi: sesi,
            progress: progress,
            waitingQc: waitingQc,
          ),
          // Tab 2: Progress — konten nyata per titik hari ini.
          const ProgressHariIniContent(),
          // Tab 3: Riwayat — konten nyata dengan filter yang berfungsi.
          const RiwayatProduksiContent(),
        ],
      ),
    );
  }
}

class _ActiveSessionsTab extends ConsumerWidget {
  const _ActiveSessionsTab({
    required this.sesi,
    required this.progress,
    required this.waitingQc,
  });

  final AsyncValue<List<ProductionSession>> sesi;
  final AsyncValue<TitikProgressData> progress;
  final AsyncValue<Map<String, QcSample>> waitingQc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => _refreshAll(ref),
      child: sesi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e is ApiException ? e.message : 'Gagal memuat sesi aktif.',
          onRetry: () => _refreshAll(ref),
        ),
        data: (items) {
          final summary = produksiHomeSummary(
            sesiAktif: items,
            progress: progress.value?.items ?? const [],
            waitingQcCount: waitingQc.value?.length ?? 0,
          );

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _ProduksiHariIniHeader(summary: summary),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    items.isEmpty ? 'Tidak ada sesi berjalan' : 'Sesi Aktif',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              items.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.factory_outlined,
                        title: 'Belum ada sesi aktif',
                        subtitle:
                            'Mulai sesi produksi baru dengan menekan tombol '
                            'Mulai Sesi di bawah.',
                        actionLabel: 'Mulai Sesi',
                        onAction: () => context.push('/produksi/mulai'),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            SliverToBoxAdapter(child: SizedBox(height: 12)),
                        itemBuilder: (context, i) => _SessionCard(
                          session: items[i],
                          hasWaitingQc:
                              waitingQc.value?.containsKey(items[i].id) ??
                              false,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

/// Invalidasi semua sumber data tab sesi aktif lalu tunggu refresh selesai.
Future<void> _refreshAll(WidgetRef ref) async {
  ref.invalidate(sesiAktifProvider);
  ref.invalidate(titikProgressProvider);
  ref.invalidate(waitingSamplesBySessionProvider);
}

/// Ringkasan "Produksi Hari Ini" — menjawab: berapa sesi, total output,
/// sesi berjalan, sesi menunggu QC, dan yang butuh perhatian.
class _ProduksiHariIniHeader extends StatelessWidget {
  const _ProduksiHariIniHeader({required this.summary});

  final ProduksiHomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final today = fmtTanggal(DateTime.now());

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadowLv2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Produksi Hari Ini — $today',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.factory_outlined, size: 20, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: 'Total Sesi',
                  value: '${summary.totalSesi}',
                  unit: 'sesi',
                ),
              ),
              Expanded(
                child: _HeaderMetric(
                  label: 'Total Output',
                  value: fmtNum(summary.totalOutput),
                  unit: '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: 'Sesi Berjalan',
                  value: '${summary.sesiBerjalan}',
                  unit: 'sesi',
                ),
              ),
              Expanded(
                child: _HeaderMetric(
                  label: 'Menunggu QC',
                  value: '${summary.sesiMenungguQc}',
                  unit: 'sample',
                ),
              ),
            ],
          ),
          if (summary.butuhPerhatian > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notification_important_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${summary.butuhPerhatian} sesi menunggu hasil uji tekan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          unit.isEmpty ? label : '$label • $unit',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                    '${session.produkNama ?? 'Produk'} — '
                    '${session.mesinNama ?? 'Mesin'}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                StatusPill(
                  label: sessionStatusLabel(session.status),
                  color: hasWaitingQc
                      ? context.colors.warning
                      : context.colors.success,
                  icon: hasWaitingQc
                      ? Icons.pending_outlined
                      : Icons.play_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.location_on_outlined,
              text: 'Titik: ${session.titikNama ?? '-'}',
            ),
            if (session.titikId != null && session.titikNama == null)
              _DetailRow(
                icon: Icons.location_on_outlined,
                text: 'Titik ID: ${session.titikId}',
              ),
            if (mulai != null)
              _DetailRow(
                icon: Icons.schedule,
                text: 'Mulai ${fmtTanggalWaktu(mulai)}',
              ),
            if (durasi != null)
              _DetailRow(
                icon: Icons.timelapse_outlined,
                text: 'Durasi ${formatDurasiSesi(durasi)}',
                highlight: theme.colorScheme.primary,
              ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (hasWaitingQc
                        ? context.colors.warning
                        : context.colors.success)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    hasWaitingQc
                        ? Icons.speed
                        : Icons.science_outlined,
                    size: 15,
                    color: hasWaitingQc
                        ? context.colors.warning
                        : context.colors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tindakan: ${nextActionForSession(hasWaitingQc: hasWaitingQc)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.science_outlined, size: 16),
                  label: const Text('Slump Test'),
                  onPressed: () => _openSlumpTest(context),
                ),
                if (hasWaitingQc)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.speed, size: 16),
                    label: const Text('Uji Tekan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.warning,
                    ),
                    onPressed: () => _openUjiTekan(context),
                  ),
                FilledButton.icon(
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
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
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SlumpTestSheet(
        sessionId: session.id,
        context: QcInspectionContext(
          produkNama: session.produkNama,
          mesinNama: session.mesinNama,
          titikNama: session.titikNama,
          mulai: session.mulai,
          jenisUji: 'slump_test',
        ),
      ),
    );
  }

  void _openUjiTekan(BuildContext context) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => UjiTekanSheet(
        sessionId: session.id,
        context: QcInspectionContext(
          produkNama: session.produkNama,
          mesinNama: session.mesinNama,
          titikNama: session.titikNama,
          mulai: session.mulai,
          jenisUji: 'uji_tekan',
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    this.highlight,
  });

  final IconData icon;
  final String text;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: context.colors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: highlight ?? context.colors.textSecondary,
                fontWeight: highlight != null
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
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
      physics: const AlwaysScrollableScrollPhysics(),
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
    if (result.delivered) {
      Navigator.of(context).pop();
      final hasil = double.parse(_hasilCtrl.text.replaceAll(',', '.'));
      final output = '${fmtNum(hasil)} $_satuan'.trim();
      messenger.showSnackBar(
        SnackBar(content: Text('Sesi selesai — $output tercatat.')),
      );
    } else if (result.queued) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text(kCopyQueued)),
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
                '${widget.session.produkNama ?? ''} • '
                '${widget.session.mesinNama ?? ''}',
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
                validator: (v) => validateHasilOutput(v ?? ''),
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