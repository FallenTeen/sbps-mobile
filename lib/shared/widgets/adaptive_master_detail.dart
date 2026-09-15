import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'app_empty_state.dart';

/// Pola list→detail adaptif (spesifikasi Bagian 2):
/// - Compact/Medium (<840dp): hanya render [masterBuilder]; saat item dipilih,
///   tetap push route detail penuh lewat [pushRouteFor] (perilaku identik lama).
/// - Expanded (>=840dp): Row split — kiri [masterBuilder] (380dp), kanan
///   [detailBuilder] atau [emptyDetailPlaceholder]. Pemilihan cukup update
///   state lokal (tanpa push), dipisah divider vertikal tipis.
///
/// Deep-link: isi [initialSelectedId] dari query `?selected=id` di route
/// master supaya masuk dari notifikasi/browser langsung menampilkan detail.
class AdaptiveMasterDetail extends StatefulWidget {
  const AdaptiveMasterDetail({
    super.key,
    required this.masterBuilder,
    required this.detailBuilder,
    required this.emptyDetailPlaceholder,
    required this.pushRouteFor,
    this.initialSelectedId,
  });

  /// Builder panel master (list + filter). [selectedId] dipakai untuk
  /// highlight item terpilih, [onSelect] menangani pemilihan sesuai mode.
  final Widget Function(
    BuildContext context,
    String? selectedId,
    void Function(String id) onSelect,
  )
  masterBuilder;

  /// Builder panel detail untuk id yang sedang dipilih.
  final Widget Function(BuildContext context, String selectedId) detailBuilder;

  /// Placeholder panel kanan saat belum ada item dipilih (Expanded only).
  final Widget emptyDetailPlaceholder;

  /// Route tujuan halaman detail saat Compact/Medium (full-page push),
  /// mis. `(id) => '/workshop/job/$id'`.
  final String Function(String id) pushRouteFor;

  /// Id awal yang dibaca dari query `?selected=` pada route master.
  final String? initialSelectedId;

  /// Lebar panel master pada mode Expanded.
  static const double masterWidth = 380.0;

  @override
  State<AdaptiveMasterDetail> createState() => AdaptiveMasterDetailState();
}

class AdaptiveMasterDetailState extends State<AdaptiveMasterDetail> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }

  /// Kembalikan panel detail ke placeholder (dipakai saat aksi di detail
  /// mengubah item, mis. "Tandai Selesai" di Workshop).
  void clearSelection() {
    setState(() => _selectedId = null);
  }

  void _onSelect(String id) {
    if (context.isExpanded) {
      setState(() => _selectedId = id);
    } else {
      context.push(widget.pushRouteFor(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final master = widget.masterBuilder(context, _selectedId, _onSelect);

    if (!context.isExpanded) return master;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: AdaptiveMasterDetail.masterWidth, child: master),
        VerticalDivider(width: 1, thickness: 1, color: context.colors.border),
        Expanded(
          child: _selectedId == null
              ? widget.emptyDetailPlaceholder
              : widget.detailBuilder(context, _selectedId!),
        ),
      ],
    );
  }
}

/// Placeholder standar panel kanan saat belum ada item dipilih (Expanded).
class MasterDetailEmptyPlaceholder extends StatelessWidget {
  const MasterDetailEmptyPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: AppEmptyState(icon: icon, title: title, subtitle: subtitle),
      ),
    );
  }
}
