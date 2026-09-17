import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/watermarked_camera_capture.dart';
import 'armada_providers.dart';
import 'models/helper.dart';

/// Presensi Helper (Pendamping) — work queue harian untuk PIC (Driver).
/// Menampilkan nama helper, status hari ini, dan action berikutnya:
/// Belum Masuk → [Presensi Masuk]; Sedang Bekerja → [Presensi Pulang];
/// Sudah Pulang → selesai.
class HelperPresensiScreen extends ConsumerStatefulWidget {
  const HelperPresensiScreen({super.key});

  @override
  ConsumerState<HelperPresensiScreen> createState() =>
      _HelperPresensiScreenState();
}

class _HelperPresensiScreenState extends ConsumerState<HelperPresensiScreen> {
  String? _submittingHelperId;

  Future<void> _submitPresensi(Helper helper, String tipe) async {
    final photo = await takeWatermarkedPhoto(ref);
    if (photo == null) return;

    setState(() {
      _submittingHelperId = helper.id;
    });

    try {
      final delivered = await ref
          .read(armadaRepositoryProvider)
          .submitHelperPresensi(
            helperId: helper.id,
            tipe: tipe,
            photoPath: photo.path,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? 'Berhasil menyimpan presensi ${helper.nama}'
                : kCopyQueued,
          ),
        ),
      );

      // Refresh list
      ref.invalidate(helpersProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan yang tidak terduga')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (_submittingHelperId == helper.id) {
            _submittingHelperId = null;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final helpersAsync = ref.watch(helpersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Pendamping'),
        actions: [
          const PortalSwitchButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(helpersProvider),
          ),
        ],
      ),
      body: helpersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  friendlyErrorMessage(
                    error,
                    fallback: 'Gagal memuat daftar helper.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(helpersProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (helpers) {
          if (helpers.isEmpty) {
            return const Center(
              child: Text('Tidak ada helper yang ditugaskan.'),
            );
          }

          final counts = _HelperCounts.fromHelpers(helpers);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(helpersProvider);
              await ref.read(helpersProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HelperSummary(counts: counts),
                const SizedBox(height: 12),
                for (final helper in helpers)
                  _HelperCard(
                    helper: helper,
                    isSubmitting: _submittingHelperId == helper.id,
                    onPresensi: (tipe) => _submitPresensi(helper, tipe),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Ringkasan ─────────────────────────────────────────────────────────────────

class _HelperCounts {
  const _HelperCounts({
    required this.belumMasuk,
    required this.bekerja,
    required this.sudahPulang,
  });

  final int belumMasuk;
  final int bekerja;
  final int sudahPulang;

  factory _HelperCounts.fromHelpers(List<Helper> helpers) {
    var belum = 0, kerja = 0, pulang = 0;
    for (final h in helpers) {
      if (h.sudahCheckOut) {
        pulang++;
      } else if (h.sudahCheckIn) {
        kerja++;
      } else {
        belum++;
      }
    }
    return _HelperCounts(
      belumMasuk: belum,
      bekerja: kerja,
      sudahPulang: pulang,
    );
  }
}

class _HelperSummary extends StatelessWidget {
  const _HelperSummary({required this.counts});

  final _HelperCounts counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _countCol(counts.belumMasuk, 'Belum Masuk', context.colors.warning),
          _countCol(counts.bekerja, 'Sedang Bekerja', context.colors.primary),
          _countCol(counts.sudahPulang, 'Sudah Pulang', context.colors.success),
        ],
      ),
    );
  }

  Widget _countCol(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

// ── Kartu Helper ─────────────────────────────────────────────────────────────

class _HelperCard extends StatelessWidget {
  const _HelperCard({
    required this.helper,
    required this.isSubmitting,
    required this.onPresensi,
  });

  final Helper helper;
  final bool isSubmitting;
  final void Function(String tipe) onPresensi;

  @override
  Widget build(BuildContext context) {
    final actionLabel = helper.nextActionLabel;
    final statusColor = helper.sudahCheckOut
        ? context.colors.success
        : helper.sudahCheckIn
        ? context.colors.primary
        : context.colors.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundImage: helper.fotoUrl != null
                  ? NetworkImage(helper.fotoUrl!)
                  : null,
              child: helper.fotoUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    helper.nama,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        helper.statusHariIniLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isSubmitting)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (actionLabel != null)
              FilledButton.tonal(
                onPressed: () => onPresensi(
                  helper.sudahCheckIn ? 'check_out' : 'check_in',
                ),
                child: Text(actionLabel),
              )
            else
              const Icon(
                Icons.check_circle_outline,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }
}