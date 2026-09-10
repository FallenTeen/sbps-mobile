import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/api_client.dart';
import 'tracking_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../core/formatters.dart';

/// Jejak lokasi satu user hari ini (GET /tracking/hari-ini/{userId}) dengan
/// visualisasi Peta OpenStreetMap interaktif dan daftar titik kronologis.
class TrailScreen extends ConsumerStatefulWidget {
  const TrailScreen({super.key, required this.userId, this.nama});

  final String userId;
  final String? nama;

  @override
  ConsumerState<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends ConsumerState<TrailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trail = ref.watch(trailProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nama == null ? 'Tracking Hari Ini' : widget.nama!),
        actions: const [PortalSwitchButton()],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined), text: 'Peta Jejak'),
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'Daftar Titik'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.refresh(trailProvider(widget.userId).future),
        child: trail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 140),
              Icon(Icons.cloud_off,
                  size: 44, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                e is ApiException ? e.message : 'Gagal memuat jejak lokasi.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(trailProvider(widget.userId)),
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          ),
          data: (data) {
            if (data.items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  const Icon(Icons.route_outlined, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada titik lokasi ${data.tanggal ?? 'hari ini'}.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final points = data.items
                .map((p) => LatLng(p.lat, p.lng))
                .toList();
            final firstPoint = points.first;
            final lastPoint = points.last;
            final firstTime = data.items.first.timestamp.toLocal();
            final lastTime = data.items.last.timestamp.toLocal();

            return TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Peta Interaktif
                Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: lastPoint,
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.sbps.mobile',
                        ),
                        if (points.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: points,
                                strokeWidth: 4.5,
                                color: Colors.blueAccent,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            // Titik Awal
                            Marker(
                              point: firstPoint,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.play_circle_fill,
                                color: Colors.green,
                                size: 36,
                              ),
                            ),
                            // Titik Akhir (Posisi Terakhir)
                            if (points.length > 1)
                              Marker(
                                point: lastPoint,
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    // Floating Summary Card
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${data.tanggal ?? 'Hari ini'} • ${data.items.length} titik',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${fmtWaktu(firstTime)} → ${fmtWaktu(lastTime)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.my_location),
                                tooltip: 'Fokus ke Posisi Terakhir',
                                onPressed: () {
                                  _mapController.move(lastPoint, 16.0);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // TAB 2: Daftar Kronologis Titik
                ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = data.items.reversed.toList()[i];
                    final isLatest = i == 0;
                    return ListTile(
                      leading: Icon(
                        isLatest ? Icons.location_pin : Icons.place_outlined,
                        color: isLatest ? Colors.red : null,
                      ),
                      title: Text(
                        fmtWaktu(item.timestamp),
                        style: TextStyle(
                          fontWeight: isLatest
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Lat: ${item.lat.toStringAsFixed(6)}, Lng: ${item.lng.toStringAsFixed(6)}',
                      ),
                      trailing: isLatest
                          ? const Chip(
                              label: Text('Terbaru'),
                              visualDensity: VisualDensity.compact,
                            )
                          : null,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
