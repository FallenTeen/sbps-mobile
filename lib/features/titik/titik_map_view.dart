import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../presensi/models/titik.dart';
import '../../shared/theme/app_theme.dart';

/// Widget reusable Peta Interaktif berbasis OpenStreetMap (OSM) dan flutter_map.
///
/// Digunakan untuk menampilkan sebaran titik kerja/proyek pada peta interaktif
/// serta memilih titik atau melihat detail titik dari marker.
class TitikMapView extends StatefulWidget {
  const TitikMapView({
    super.key,
    required this.titikList,
    this.selectedTitikId,
    this.onSelect,
    this.onDetail,
    this.height,
    this.isEmbedded = false,
    this.emptyMessage = 'Belum ada titik kerja dengan koordinat valid.',
  });

  /// Daftar titik yang akan ditampilkan pada peta.
  final List<Titik> titikList;

  /// ID titik yang sedang dipilih (untuk visual highlight pada marker).
  final String? selectedTitikId;

  /// Callback ketika user memilih titik dari bottom sheet marker.
  final ValueChanged<Titik>? onSelect;

  /// Callback ketika user membuka detail titik dari bottom sheet marker (misal di Dashboard).
  final ValueChanged<Titik>? onDetail;

  /// Tinggi custom widget jika disematkan dalam container/list.
  final double? height;

  /// Apakah peta disematkan di dalam scrollable / kartu.
  final bool isEmbedded;

  /// Pesan saat list kosong atau tidak ada koordinat valid.
  final String emptyMessage;

  @override
  State<TitikMapView> createState() => _TitikMapViewState();
}

class _TitikMapViewState extends State<TitikMapView> {
  final MapController _mapController = MapController();
  bool _initialized = false;

  List<Titik> get _validTitik =>
      widget.titikList.where((t) => t.hasValidCoordinates).toList();

  List<LatLng> get _validPoints =>
      _validTitik.map((t) => LatLng(t.latitude, t.longitude)).toList();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitAllMarkers() {
    final points = _validPoints;
    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 15.0);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(48.0),
          maxZoom: 16.0,
        ),
      );
    }
  }

  void _showTitikBottomSheet(Titik titik) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isSelected = widget.selectedTitikId == titik.id;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      radius: 22,
                      child: Icon(
                        Icons.place,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titik.nama,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (titik.displayProyek != null &&
                              titik.displayProyek!.isNotEmpty)
                            Text(
                              titik.displayProyek!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (titik.status != null && titik.status!.isNotEmpty)
                      Chip(
                        label: Text(
                          titik.status!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: titik.status == 'aktif'
                                ? Colors.green.shade800
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        backgroundColor: titik.status == 'aktif'
                            ? Colors.green.shade50
                            : theme.colorScheme.surfaceContainerHighest,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),

                // Detail properties
                if (titik.radiusPresensiMeter > 0)
                  _InfoRow(
                    icon: Icons.radar,
                    label: 'Radius Presensi',
                    value: '${titik.radiusPresensiMeter.round()} meter',
                  ),
                _InfoRow(
                  icon: Icons.my_location,
                  label: 'Koordinat',
                  value:
                      '${titik.latitude.toStringAsFixed(6)}, ${titik.longitude.toStringAsFixed(6)}',
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    if (widget.onDetail != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            widget.onDetail!(titik);
                          },
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Detail Titik'),
                        ),
                      ),
                    if (widget.onDetail != null && widget.onSelect != null)
                      const SizedBox(width: 12),
                    if (widget.onSelect != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            widget.onSelect!(titik);
                          },
                          icon: Icon(
                            isSelected
                                ? Icons.check
                                : Icons.check_circle_outline,
                          ),
                          label: Text(
                            isSelected ? 'Sudah Dipilih' : 'Pilih Titik Ini',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final validPoints = _validPoints;

    // Handle empty or invalid coordinates
    if (validPoints.isEmpty) {
      return Container(
        height: widget.height ?? 260,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.map_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              widget.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      );
    }

    // Default center & bounds
    final initialCenter = validPoints.first;
    final mapWidget = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: validPoints.length == 1 ? 15.0 : 12.0,
            initialCameraFit: validPoints.length > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(validPoints),
                    padding: const EdgeInsets.all(48.0),
                    maxZoom: 16.0,
                  )
                : null,
            onMapReady: () {
              if (!_initialized && validPoints.length > 1) {
                _initialized = true;
                _fitAllMarkers();
              }
            },
          ),
          children: [
            // Tile Layer OpenStreetMap
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sbps.mobile',
            ),

            // Attribution Wajib OSM
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  '© OpenStreetMap contributors',
                  onTap: () {},
                ),
              ],
            ),

            // Marker Layer
            MarkerLayer(
              markers: [
                for (final titik in _validTitik)
                  Marker(
                    point: LatLng(titik.latitude, titik.longitude),
                    width: 50,
                    height: 50,
                    child: _TitikMapMarker(
                      titik: titik,
                      isSelected: widget.selectedTitikId == titik.id,
                      onTap: () => _showTitikBottomSheet(titik),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Floating Control: Fit Bounds
        Positioned(
          top: 12,
          right: 12,
          child: Card(
            elevation: 3,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Pusatkan Semua Titik',
              icon: const Icon(Icons.crop_free),
              onPressed: _fitAllMarkers,
            ),
          ),
        ),

        // Floating Counter Titik
        Positioned(
          top: 12,
          left: 12,
          child: Card(
            elevation: 3,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place, size: 16, color: context.colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${_validTitik.length} Titik',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.height != null) {
      return SizedBox(
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: mapWidget,
        ),
      );
    }

    return mapWidget;
  }
}

class _TitikMapMarker extends StatelessWidget {
  const _TitikMapMarker({
    required this.titik,
    required this.isSelected,
    required this.onTap,
  });

  final Titik titik;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.location_on,
              size: isSelected ? 48 : 38,
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.red.shade600,
            ),
            Positioned(
              top: isSelected ? 8 : 6,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.business,
                  size: 10,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
