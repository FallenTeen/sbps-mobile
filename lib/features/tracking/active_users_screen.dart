import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/searchable_list_header.dart';
import 'models.dart';
import 'tracking_providers.dart';
import 'tracking_rules.dart';
import 'widgets/track_location_actions.dart';

enum _StatusFilter { semua, segar, stale }

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
  bool _showMap = false;
  String _query = '';
  _StatusFilter _statusFilter = _StatusFilter.semua;

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

  Future<void> _showLocationActions(ActiveUser user) async {
    final url = resolveLocationUrl(
      fromServer: user.googleMapsUrlFromServer,
      lat: user.lastLat,
      lng: user.lastLng,
    );
    final messenger = ScaffoldMessenger.of(context);
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Belum ada koordinat GPS untuk dibuka.')),
      );
      return;
    }
    await showTrackLocationActions(context, url: url, nama: user.nama);
  }

  void _resetFilters() {
    setState(() {
      _query = '';
      _statusFilter = _StatusFilter.semua;
    });
  }

  List<ActiveUser> _applyFilters(List<ActiveUser> items) {
    final now = DateTime.now();
    Iterable<ActiveUser> result = items;

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where(
        (u) =>
            u.nama.toLowerCase().contains(q) ||
            (u.titik ?? '').toLowerCase().contains(q),
      );
    }

    if (_statusFilter != _StatusFilter.semua) {
      result = result.where((u) {
        final state = trackingFreshness(u.lastSeen, now: now).state;
        return _statusFilter == _StatusFilter.segar
            ? state == TrackingFreshnessState.fresh
            : state == TrackingFreshnessState.stale;
      });
    }

    return result.toList();
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
          error: (e, _) => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal memuat data tracking',
            subtitle: e is ApiException ? e.message : null,
            actionLabel: 'Coba lagi',
            onAction: () => ref.invalidate(activeUsersProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.person_search_outlined,
                title: 'Belum ada karyawan aktif',
                subtitle: 'Belum ada karyawan dengan presensi aktif hari ini.',
              );
            }

            final now = DateTime.now();
            final sorted = sortActiveUsers(items);
            final filtered = _applyFilters(sorted);

            var fresh = 0;
            var stale = 0;
            for (final u in sorted) {
              switch (trackingFreshness(u.lastSeen, now: now).state) {
                case TrackingFreshnessState.fresh:
                  fresh++;
                case TrackingFreshnessState.stale:
                  stale++;
                case TrackingFreshnessState.noData:
                  break;
              }
            }

            return ResponsiveCenter(
              maxWidth: AppBreakpoints.maxContentWidth,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _StatsRow(
                      total: sorted.length,
                      fresh: fresh,
                      stale: stale,
                    ),
                  ),
                  SearchableListHeader(
                    hintText: 'Cari nama atau titik kerja...',
                    onChanged: (v) => setState(() => _query = v),
                    child: _StatusFilterChips(
                      value: _statusFilter,
                      onChanged: (v) => setState(() => _statusFilter = v),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _ViewToggle(
                    value: _showMap,
                    onChanged: (map) => setState(() => _showMap = map),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? AppEmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'Tidak ada yang cocok',
                            subtitle:
                                'Coba ubah kata kunci pencarian atau filter status.',
                            actionLabel: 'Reset Filter',
                            onAction: _resetFilters,
                          )
                        : _showMap
                        ? _ActiveUsersMap(
                            users: filtered,
                            onTapUser: _showLocationActions,
                          )
                        : _ActiveUsersList(users: filtered),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Ringkasan KPI: total user presensi aktif, berapa yang update-nya segar,
/// dan berapa yang perlu dicek (stale) — semua hitungan dari timestamp
/// AKTUAL server, senada dengan pola KPI di Monitoring Armada.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.fresh,
    required this.stale,
  });

  final int total;
  final int fresh;
  final int stale;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.groups_outlined,
            label: 'Aktif hari ini',
            value: '$total',
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.sensors,
            label: 'Update segar',
            value: '$fresh',
            color: colors.success,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.warning_amber_rounded,
            label: 'Perlu dicek',
            value: '$stale',
            color: stale > 0 ? colors.warning : colors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
          boxShadow: AppTheme.shadowLv1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter status (Semua/Segar/Perlu dicek) — child dari [SearchableListHeader].
class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.value, required this.onChanged});

  final _StatusFilter value;
  final ValueChanged<_StatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: value == _StatusFilter.semua,
            onSelected: (_) => onChanged(_StatusFilter.semua),
          ),
          ChoiceChip(
            label: const Text('Segar'),
            selected: value == _StatusFilter.segar,
            onSelected: (_) => onChanged(_StatusFilter.segar),
          ),
          ChoiceChip(
            label: const Text('Perlu dicek'),
            selected: value == _StatusFilter.stale,
            onSelected: (_) => onChanged(_StatusFilter.stale),
          ),
        ],
      ),
    );
  }
}

/// Toggle Daftar / Peta — tetap di atas konten agar user gampang berpindah.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Daftar'),
              icon: Icon(Icons.view_agenda_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Peta'),
              icon: Icon(Icons.map_outlined),
            ),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

/// List/grid kartu user (tampilan default), dipisah supaya mudah berganti
/// tampilan. Grid dipakai mulai breakpoint Medium (tablet) ke atas.
class _ActiveUsersList extends StatelessWidget {
  const _ActiveUsersList({required this.users});

  final List<ActiveUser> users;

  @override
  Widget build(BuildContext context) {
    if (!context.isTablet) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _UserCard(user: users[i]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.responsiveValue(
          compact: 1,
          medium: 2,
          expanded: 3,
        ),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // Tinggi TETAP (bukan aspect ratio): kartu punya 4 baris konten
        // (nama+badge, titik, aktif sejak, lokasi terakhir, footer chip) —
        // aspect ratio membuat tinggi ikut menyusut saat kolom melebar
        // (grid 3 kolom di layar lebar → kartu overflow). Nilai ini punya
        // slack untuk font scaling ~130%.
        mainAxisExtent: 220,
      ),
      itemCount: users.length,
      itemBuilder: (context, i) => _UserCard(user: users[i]),
    );
  }
}

/// Peta posisi seluruh user aktif (marker = koordinat GPS TERAKHIR dari
/// server, bukan koordinat titik kerja). Ketuk marker → aksi Buka/Bagikan
/// Lokasi. State dihitung jujur dari timestamp server: marker hijau = segar,
/// oranye = stale.
class _ActiveUsersMap extends StatefulWidget {
  const _ActiveUsersMap({required this.users, required this.onTapUser});

  final List<ActiveUser> users;
  final ValueChanged<ActiveUser> onTapUser;

  @override
  State<_ActiveUsersMap> createState() => _ActiveUsersMapState();
}

class _ActiveUsersMapState extends State<_ActiveUsersMap> {
  final MapController _mapController = MapController();
  bool _initialized = false;

  List<ActiveUser> get _withCoords => widget.users
      .where((u) => u.lastLat != null && u.lastLng != null)
      .toList();

  List<LatLng> get _points =>
      _withCoords.map((u) => LatLng(u.lastLat!, u.lastLng!)).toList();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitAll() {
    final points = _points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 14.0);
    } else {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
          maxZoom: 16,
        ),
      );
    }
  }

  void _fitOnceOnReady() {
    if (_initialized || _points.length <= 1) {
      _initialized = true;
      return;
    }
    _initialized = true;
    _fitAll();
  }

  @override
  Widget build(BuildContext context) {
    final withCoords = _withCoords;
    final now = DateTime.now();

    if (withCoords.isEmpty) {
      return const AppEmptyState(
        icon: Icons.map_outlined,
        title: 'Belum ada koordinat GPS',
        subtitle: 'Belum ada koordinat GPS untuk ditampilkan di peta.',
      );
    }

    final points = _points;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.length == 1
                ? points.first
                : const LatLng(0, 0),
            initialZoom: points.length == 1 ? 14.0 : 5.0,
            initialCameraFit: points.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(points),
                    padding: const EdgeInsets.all(48),
                    maxZoom: 16,
                  )
                : null,
            onMapReady: () {
              _fitOnceOnReady();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sbps.mobile',
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
            MarkerLayer(
              markers: [
                for (final u in withCoords)
                  Marker(
                    point: LatLng(u.lastLat!, u.lastLng!),
                    width: 130,
                    height: 60,
                    child: _UserMapMarker(
                      user: u,
                      freshness: trackingFreshness(u.lastSeen, now: now),
                      onTap: () => widget.onTapUser(u),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Card(
            elevation: 3,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Pusatkan Semua',
              icon: const Icon(Icons.crop_free),
              onPressed: _fitAll,
            ),
          ),
        ),
      ],
    );
  }
}

/// Marker peta user aktif — pin (warna sesuai kesegaran) + label nama.
class _UserMapMarker extends StatelessWidget {
  const _UserMapMarker({
    required this.user,
    required this.freshness,
    required this.onTap,
  });

  final ActiveUser user;
  final TrackingFreshness freshness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = context.colors;
    final color = switch (freshness.state) {
      TrackingFreshnessState.fresh => appColors.success,
      TrackingFreshnessState.stale => appColors.warning,
      TrackingFreshnessState.noData => appColors.textMuted,
    };
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      // FittedBox(scaleDown) — Marker di flutter_map punya width/height TETAP
      // (dari MarkerLayer); jika konten (ikon pin + label nama) sedikit lebih
      // tinggi dari yang dialokasikan (mis. metrik font platform berbeda,
      // atau pengaturan font besar), ini menyusutkan tampilan alih-alih
      // overflow, bukannya memotong/error.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 36, color: color),
            Container(
              constraints: const BoxConstraints(maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                user.nama,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = context.colors;
    final shareUrl = resolveLocationUrl(
      fromServer: user.googleMapsUrlFromServer,
      lat: user.lastLat,
      lng: user.lastLng,
    );

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
                              color: colorScheme.outline,
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
                  Icon(Icons.schedule, size: 15, color: colorScheme.outline),
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
                    color: f.isStale ? appColors.warning : colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lokasiTerakhirText(user.lastSeen),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: f.isStale
                            ? appColors.warning
                            : colorScheme.onSurfaceVariant,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shareUrl != null)
                        IconButton(
                          tooltip: 'Buka / Bagikan Lokasi',
                          icon: const Icon(Icons.share_location),
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          color: colorScheme.primary,
                          onPressed: () => showTrackLocationActions(
                            context,
                            url: shareUrl,
                            nama: user.nama,
                          ),
                        ),
                      Text(
                        'Jejak hari ini',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
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
    final appColors = context.colors;
    final color = switch (freshness.state) {
      TrackingFreshnessState.fresh => appColors.success,
      TrackingFreshnessState.stale => appColors.warning,
      TrackingFreshnessState.noData => appColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(freshness),
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
