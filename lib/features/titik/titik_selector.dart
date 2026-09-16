import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../presensi/models/titik.dart';
import 'titik_map_view.dart';

enum TitikSelectorMode { daftar, peta }

/// Widget hybrid selector yang memungkinkan user memilih titik kerja/proyek
/// melalui mode "Daftar" (dropdown/list lama) atau mode "Peta" (OSM interaktif).
///
/// Fitur utama:
/// 1. Lazy Loading: Map tidak di-load ketika mode "Daftar" aktif (menghemat kuota/baterai).
/// 2. Sinkronisasi 2 arah antara pilihan di Peta dan Daftar.
/// 3. Reusable untuk form submit maupun pemilihan titik kerja.
class TitikSelector extends StatefulWidget {
  const TitikSelector({
    super.key,
    required this.titikList,
    required this.selectedTitik,
    required this.onChanged,
    required this.listBuilder,
    this.initialMode = TitikSelectorMode.daftar,
    this.mapHeight = 320,
    this.showToggle = true,
    this.userPosition,
  });

  /// Daftar titik yang tersedia.
  final List<Titik> titikList;

  /// Titik yang saat ini terpilih.
  final Titik? selectedTitik;

  /// Callback ketika titik dipilih (baik dari dropdown/list maupun peta).
  final ValueChanged<Titik?> onChanged;

  /// Builder untuk merender UI mode "Daftar" (misal dropdown atau ListView tile yang sudah ada).
  final Widget Function(BuildContext context, Titik? selectedTitik) listBuilder;

  /// Mode tampilan awal.
  final TitikSelectorMode initialMode;

  /// Tinggi peta pada mode "Peta".
  final double mapHeight;

  /// Apakah menampilkan SegmentedButton toggle di atas.
  final bool showToggle;

  /// Posisi user saat ini — ditampilkan sebagai penanda biru di peta bila ada.
  final LatLng? userPosition;

  @override
  State<TitikSelector> createState() => _TitikSelectorState();
}

class _TitikSelectorState extends State<TitikSelector> {
  late TitikSelectorMode _currentMode;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showToggle)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SegmentedButton<TitikSelectorMode>(
                  segments: const [
                    ButtonSegment(
                      value: TitikSelectorMode.daftar,
                      icon: Icon(Icons.format_list_bulleted, size: 18),
                      label: Text('Daftar'),
                    ),
                    ButtonSegment(
                      value: TitikSelectorMode.peta,
                      icon: Icon(Icons.map_outlined, size: 18),
                      label: Text('Peta'),
                    ),
                  ],
                  selected: {_currentMode},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      setState(() => _currentMode = set.first);
                    }
                  },
                ),
                if (widget.selectedTitik != null)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        widget.selectedTitik!.nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Lazy load: Jika mode daftar, render listBuilder TANPA me-mount TitikMapView
        if (_currentMode == TitikSelectorMode.daftar)
          widget.listBuilder(context, widget.selectedTitik)
        else
          TitikMapView(
            titikList: widget.titikList,
            selectedTitikId: widget.selectedTitik?.id,
            userPosition: widget.userPosition,
            height: widget.mapHeight,
            onSelect: (titik) {
              widget.onChanged(titik);
            },
          ),
      ],
    );
  }
}
