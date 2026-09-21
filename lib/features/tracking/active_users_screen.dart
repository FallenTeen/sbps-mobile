import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'models.dart';
import 'tracking_providers.dart';
import 'tracking_rules.dart';
import 'widgets/track_location_actions.dart';

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
                _ViewToggle(
                  value: _showMap,
                  onChanged: (map) => setState(() => _showMap = map),
                ),
                Expanded(
                  child: _showMap
                      ? _ActiveUsersMap(
                          users: sorted,
                          onTapUser: _showLocationActions,
                        )
                      : _ActiveUsersList(users: sorted),
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

/// List/grid kartu user (tampilan default), sama seperti sebelumnya —
/// dipisah supaya mudah berganti tampilan.
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
        childAspectRatio: 3.0,
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
      return ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.map_outlined, size: 44),
          SizedBox(height: 12),
          Text(
            'Belum ada koordinat GPS untuk ditampilkan di peta.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    final points = _points;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: points.length == 1 ? points.first : const LatLng(0, 0),
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
                    height: 54,
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
    final color = switch (freshness.state) {
      TrackingFreshnessState.fresh => Colors.green.shade700,
      TrackingFreshnessState.stale => Colors.orange.shade700,
      TrackingFreshnessState.noData => Colors.grey.shade600,
    };
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
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
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (shareUrl != null)
                        IconButton(
                          tooltip: 'Buka / Bagikan Lokasi',
                          icon: const Icon(Icons.share_location),
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          color: colors.primary,
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
                          color: colors.primary,
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