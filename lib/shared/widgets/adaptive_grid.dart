import 'package:flutter/widgets.dart';

import '../theme/breakpoints.dart';

/// Grid responsif berbasis jumlah kolom per breakpoint
/// (Compact / Medium / Expanded).
///
/// Memakai helper `context.responsiveValue()` dari `breakpoints.dart` supaya
/// logika breakpoint tidak diduplikasi di setiap layar. Item diberi lebar
/// merata mengikuti jumlah kolom; tinggi item mengikuti isi kontennya (Wrap),
/// bukan kotak kaku seperti `GridView.count`.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.compactColumns = 1,
    this.mediumColumns = 2,
    this.expandedColumns = 2,
    this.spacing = 12,
  });

  /// Item yang ditampilkan dalam grid, berurutan kiri-ke-kanan / atas-ke-bawah.
  final List<Widget> children;

  /// Jumlah kolom di breakpoint Compact (<600dp).
  final int compactColumns;

  /// Jumlah kolom di breakpoint Medium (600–839dp).
  final int mediumColumns;

  /// Jumlah kolom di breakpoint Expanded (≥840dp).
  final int expandedColumns;

  /// Jarak antar item, baik horizontal (kolom) maupun vertikal (baris).
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final requestedColumns = context.responsiveValue(
      compact: compactColumns,
      medium: mediumColumns,
      expanded: expandedColumns,
    );

    final columnCount = requestedColumns.clamp(1, children.length).toInt();
    if (columnCount == 1) return _stackChildren(children);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth) {
          return _stackChildren(children);
        }

        final itemWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }

  /// Representasi 1-kolom: tiap item ditumpuk vertikal penuh selebar parent.
  Widget _stackChildren(List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          items[i],
        ],
      ],
    );
  }
}
