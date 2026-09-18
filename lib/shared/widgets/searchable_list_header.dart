import 'package:flutter/material.dart';

/// Header pencarian reusable: text field search + optional filter row di
/// bawahnya yang bisa dilipat ("collapsible").
///
/// Dipakai di layar list panjang (RiwayatQC, RiwayatServis, RiwayatProduksi,
/// Notifikasi) supaya user bisa mencari item tanpa harus scroll.
///
/// Widget ini **tidak mengelola state filter** — ia hanya menampilkan search
/// field dan meneruskan query ke parent lewat `onChanged`. Parent screen
/// bertanggung jawab menyimpan query dan memanggil `setState`.
class SearchableListHeader extends StatefulWidget {
  const SearchableListHeader({
    super.key,
    required this.onChanged,
    this.hintText = 'Cari...',
    this.child,
    this.initialValue,
    this.collapsible = true,
    this.initialExpanded = true,
  });

  /// Callback setiap user mengetik atau menghapus query.
  final ValueChanged<String> onChanged;

  /// Placeholder di search field. Default: `'Cari...'`.
  final String hintText;

  /// Widget filter tambahan di bawah search field (mis. ChoiceChip/Dropdown).
  /// Diletakkan dengan `SizedBox(height:8)` otomatis di atasnya.
  final Widget? child;

  /// Nilai awal query (opsional, jarang dipakai).
  final String? initialValue;

  /// Jika `true` (default), [child] dibungkus toggle lipat
  /// ("Sembunyikan/Tampilkan filter") supaya area filter tidak selalu
  /// memakan ruang vertikal di layar compact. Matikan untuk struktur filter
  /// yang terdiri dari beberapa section mandiri.
  final bool collapsible;

  /// Status awal lipatan. Default `true` (filter tampil), jadi perilaku
  /// awal identik dengan sebelum fitur ini.
  final bool initialExpanded;

  @override
  State<SearchableListHeader> createState() => _SearchableListHeaderState();
}

class _SearchableListHeaderState extends State<SearchableListHeader> {
  late final TextEditingController _controller;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _expanded = widget.initialExpanded;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final showToggle = widget.collapsible && widget.child != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            onChanged: (v) {
              setState(() {}); // refresh clear button visibility
              widget.onChanged(v);
            },
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Hapus pencarian',
                      onPressed: () {
                        _controller.clear();
                        setState(() {});
                        widget.onChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
          if (showToggle)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 48),
                ),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                ),
                label: Text(
                  _expanded ? 'Sembunyikan filter' : 'Tampilkan filter',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          if (_expanded && widget.child != null) ...[
            const SizedBox(height: 8),
            widget.child!,
          ],
        ],
      ),
    );
  }
}
