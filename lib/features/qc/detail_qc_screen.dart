import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/api_client.dart';
import 'qc_providers.dart';
import 'status_badge.dart';

/// Detail QC sample: info sample + info sesi produksi terkait
/// (produk, mesin, titik, operator, waktu mulai/selesai) — Fase A2.5.
class DetailQcScreen extends ConsumerWidget {
  const DetailQcScreen({super.key, required this.sampleId});

  final String sampleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(qcDetailProvider(sampleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail QC')),
      body: ResponsiveCenter(
        maxWidth: AppBreakpoints.maxContentWidth,
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(qcDetailProvider(sampleId).future),
          child: detail.when(
            loading: () => const SkeletonDetailView(),
            error: (e, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Gagal Memuat Detail QC',
                  subtitle:
                      e is ApiException ? e.message : 'Gagal memuat detail QC.',
                  actionLabel: 'Coba Lagi',
                  onAction: () =>
                      ref.invalidate(qcDetailProvider(sampleId)),
                ),
              ],
            ),
            data: (s) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                StaggeredEntrance(
                  index: 0,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sample QC',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              QcStatusBadge(status: s.status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _row('Nilai slump', _fmt(s.nilaiSlump)),
                          if (s.hasilUjiTekan != null)
                            _row('Hasil uji tekan', '${_fmt(s.hasilUjiTekan)} MPa'),
                          if (s.tanggalUjiTekanRencana != null)
                            _row('Rencana uji tekan', s.tanggalUjiTekanRencana!),
                          _row('Catatan', s.catatan ?? '-'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredEntrance(
                  index: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sesi Produksi',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          _row('Produk', s.produkNama ?? '-'),
                          _row('Mesin', s.mesinNama ?? '-'),
                          _row('Titik', s.titikNama ?? '-'),
                          _row('Operator', s.operatorNama ?? '-'),
                          _row('Mulai', _dt(s.sesiMulai)),
                          _row('Selesai', _dt(s.sesiSelesai)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

String _fmt(double? n) => n == null
    ? '-'
    : n % 1 == 0
        ? n.toInt().toString()
        : n.toStringAsFixed(1);

String _dt(DateTime? t) {
  if (t == null) return '-';
  final l = t.toLocal();
  return '${l.day}/${l.month}/${l.year} '
      '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}
