import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../auth/auth_providers.dart';
import 'models/production_session.dart';
import 'produksi_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Ringkasan produksi untuk Mandor Titik: sesi aktif di titiknya,
/// output hari ini, progress per titik, dan shortcut aksi.
class ProduksiRingkasanScreen extends ConsumerWidget {
  const ProduksiRingkasanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final sesiAsync = ref.watch(sesiAktifProvider);
    final progressAsync = ref.watch(titikProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Produksi'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sesiAktifProvider);
          ref.invalidate(titikProgressProvider);
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _GreetingSection(userName: user?.name),
            const SizedBox(height: 16),
            _ActiveSessionsSection(sesiAsync: sesiAsync),
            const SizedBox(height: 16),
            _ProgressSection(progressAsync: progressAsync),
            const SizedBox(height: 16),
            _QuickActions(),
          ],
        ),
      ),
    );
  }
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.engineering,
              size: 36,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${userName ?? 'Mandor'}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'Berikut ringkasan produksi hari ini.',
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section: Sesi produksi aktif.
class _ActiveSessionsSection extends StatelessWidget {
  const _ActiveSessionsSection({required this.sesiAsync});

  final AsyncValue<List<ProductionSession>> sesiAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.play_circle_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Sesi Aktif',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        sesiAsync.when(
          loading: () => const SkeletonCard(),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                friendlyErrorMessage(e, fallback: 'Gagal memuat sesi.'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 36,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        const Text('Belum ada sesi aktif'),
                        const SizedBox(height: 4),
                        Text(
                          'Mulai sesi produksi baru untuk mencatat jam kerja '
                          'dan progres lapangan.',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [for (final s in sessions) _SessionCard(session: s)],
            );
          },
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final ProductionSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = session.mulai != null
        ? DateTime.now().difference(session.mulai!)
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.1),
          child: Icon(Icons.play_arrow, color: context.colors.success),
        ),
        title: Text(
          '${session.produkNama ?? '-'} • ${session.mesinNama ?? '-'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (session.titikNama != null)
              Text(
                'Titik: ${session.titikNama}',
                style: theme.textTheme.bodySmall,
              ),
            if (duration != null)
              Text(
                'Berjalan: ${_formatDuration(duration)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/produksi/sesi-aktif'),
      ),
    );
  }
}

/// Section: Progress produksi per titik.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.progressAsync});

  final AsyncValue<TitikProgressData> progressAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.analytics_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Progress Hari Ini',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        progressAsync.when(
          loading: () => const SkeletonCard(),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                friendlyErrorMessage(e, fallback: 'Gagal memuat progress.'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.bar_chart,
                          size: 36,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        const Text('Belum ada produksi hari ini'),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.tanggal.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Tanggal: ${data.tanggal}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final item in data.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProgressTile(item: item),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({required this.item});

  final TitikProgressItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.place, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.titikNama ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.jumlahSesi} sesi',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            fmtNum(item.totalOutput),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section: Shortcut aksi cepat.
class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.flash_on_outlined,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'Aksi Cepat',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.add_circle_outline,
                title: 'Mulai Sesi',
                subtitle: 'Produksi baru',
                onTap: () => context.push('/produksi/mulai'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.list_alt_outlined,
                title: 'Sesi Aktif',
                subtitle: 'Lihat & selesaikan',
                onTap: () => context.push('/produksi/sesi-aktif'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.history,
                title: 'Riwayat',
                subtitle: 'Riwayat produksi',
                onTap: () => context.push('/produksi/riwayat'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionCard(
                icon: Icons.trending_up,
                title: 'Progress',
                subtitle: 'Output hari ini',
                onTap: () => context.push('/produksi/progress'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) {
  if (d.inHours > 0) {
    return '${d.inHours}j ${d.inMinutes.remainder(60)}m';
  }
  return '${d.inMinutes}m';
}
