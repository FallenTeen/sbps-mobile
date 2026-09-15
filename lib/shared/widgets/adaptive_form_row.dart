import 'package:flutter/widgets.dart';

import '../theme/breakpoints.dart';

/// Merangkai 2+ field pendek yang saling independen dalam satu baris
/// horizontal di tablet landscape, dan tetap bertumpuk vertikal di layar
/// lain (perilaku Compact/Medium identik dengan form 1-kolom biasa).
///
/// Syarat pemakaian: field harus secara semantik independen (masing-masing
/// bisa diisi tanpa bergantung pada isi field lain). Jangan dipakai untuk
/// field dengan validasi berurutan/kondisional.
class AdaptiveFormRow extends StatelessWidget {
  const AdaptiveFormRow({super.key, required this.fields, this.spacing = 12});

  /// Field yang dirangkai berdampingan (umumnya 2 field pendek & related).
  final List<Widget> fields;

  /// Jarak antar field, baik horizontal (baris) maupun vertikal (kolom).
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final sideBySide = context.isExpanded && context.isLandscape;

    if (!sideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) SizedBox(height: spacing),
            fields[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < fields.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: fields[i]),
        ],
      ],
    );
  }
}
