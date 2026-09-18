import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'models.dart';
import 'tracking_providers.dart';
import 'tracking_rules.dart';

/// Daftar user yang masih ber-presensi aktif hari ini + status GPS terkini
/// — khusus Owner/Admin Keuangan. Auto-refresh tiap 60 detik.
///
/// Freshness/stale-state dihitung dari timestamp AKTUAL server (`last_seen`):
/// user yang lambat diperlihatkan jujur ("Lokasi terakhir X menit lalu"),
/// tidak pernah dipajang seolah realtime.
class ActiveUsersScreen extends ConsumerStatefulWidget {
  const ActiveUsersScreen({super.key});

  @override
  ConsumerState<ActiveUsersScreen> createState() => _ActiveUsersScreenState();
}

class _ActiveUsersScreenState extends ConsumerState<ActiveUsersScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(activeUsersProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(activeUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracking User Aktif'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(activeUsersProvider.future),
        child: users.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 140),
              Icon(
                Icons.cloud_off,
                size: 44,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                e is ApiException ? e.message : 'Gagal memuat data tracking.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(activeUsersProvider),
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Icon(Icons.person_search_outlined, size: 44),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada karyawan dengan presensi aktif hari ini.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final sorted = sortActiveUsers(items);

            return Column(
              children: [
                _SummaryBanner(users: sorted),
                Expanded(
                  child: context.isTablet
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: context.responsiveValue(
                                  compact: 1,
                                  medium: 2,
                                  expanded: 3,
                                ),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 3.0,
                              ),
                          itemCount: sorted.length,
                          itemBuilder: (context, i) =>
                              _UserCard(user: sorted[i]),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: sorted.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) =>
                              _UserCard(user: sorted[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Banner ringkas: berapa update segar vs stale — semua hitungan dari
/// timestamp aktual server.
class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.users});

  final List<ActiveUser> users;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    var fresh = 0;
    var stale = 0;
    for (final u in users) {
      switch (trackingFreshness(u.lastSeen, now: now).state) {
        case TrackingFreshnessState.fresh:
          fresh++;
        case TrackingFreshnessState.stale:
          stale++;
        case TrackingFreshnessState.noData:
          break;
      }
    }

    final staleText = stale > 0
        ? '$fresh segar • $stale update lama'
        : '$fresh update segar';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: stale > 0
            ? Colors.orange.shade50
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: stale > 0 ? Colors.orange.shade300 : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            stale > 0 ? Icons.warning_amber_rounded : Icons.sensors,
            size: 18,
            color: stale > 0
                ? Colors.orange.shade800
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${users.length} user presensi aktif • $staleText. '
              'Data GPS sesuai catatan server.',
              style: TextStyle(
                fontSize: 12,
                color: stale > 0
                    ? Colors.orange.shade900
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final ActiveUser user;

  @override
  Widget build(BuildContext context) {
    final f = trackingFreshness(user.lastSeen);
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          '/tracking/pengguna-aktif/hari-ini/${user.userId}',
          extra: user.nama,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(user.nama.isNotEmpty ? user.nama[0] : '?'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nama,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: colors.outline,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                user.titik ?? 'Titik belum diketahui',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FreshnessChip(freshness: f),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 15, color: colors.outline),
                  const SizedBox(width: 6),
                  Text(
                    aktifSejakText(user.aktifSejak),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    f.isStale ? Icons.location_off : Icons.my_location,
                    size: 15,
                    color: f.isStale
                        ? Colors.orange.shade800
                        : colors.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lokasiTerakhirText(user.lastSeen),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: f.isStale
                            ? Colors.orange.shade900
                            : colors.onSurfaceVariant,
                        fontWeight: f.isStale
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${user.pointCount} titik GPS'),
                  ),
                  Text(
                    'Jejak hari ini',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreshnessChip extends StatelessWidget {
  const _FreshnessChip({required this.freshness});

  final TrackingFreshness freshness;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (freshness.state) {
      TrackingFreshnessState.fresh => (Colors.green.shade100, Colors.green.shade900),
      TrackingFreshnessState.stale => (Colors.orange.shade100, Colors.orange.shade900),
      TrackingFreshnessState.noData => (Colors.grey.shade200, Colors.grey.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(freshness),
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}