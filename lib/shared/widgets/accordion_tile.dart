import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptic_map.dart';

/// Accordion teranimasi pengganti ExpansionTile.
///
/// [expanded] dikontrol parent sehingga bisa auto-advance (mis. checklist
/// lompat ke bagian yang belum terisi) sambil tetap teranimasi.
/// Durasi default 250ms, curve easeInOutCubic, chevron berputar 180 derajat.
class AccordionTile extends StatefulWidget {
  const AccordionTile({
    super.key,
    required this.header,
    required this.content,
    this.expanded = false,
    this.onToggle,
    this.margin,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOutCubic,
    this.headerPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 12,
    ),
  });

  final Widget header;
  final Widget content;
  final bool expanded;

  /// Dipanggil saat user mengetuk header. Parent memutakhirkan [expanded].
  final VoidCallback? onToggle;

  final EdgeInsetsGeometry? margin;
  final Duration duration;
  final Curve curve;
  final EdgeInsetsGeometry headerPadding;

  @override
  State<AccordionTile> createState() => _AccordionTileState();
}

class _AccordionTileState extends State<AccordionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sizeFactor;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          // Buang content setelah animasi tutup selesai.
          setState(() {});
        }
      });
    _sizeFactor = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: widget.curve.flipped,
    );
    _turns = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
        reverseCurve: widget.curve.flipped,
      ),
    );
    _controller.value = widget.expanded ? 1 : 0;
  }

  @override
  void didUpdateWidget(AccordionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _showContent => widget.expanded || _controller.isAnimating;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: widget.expanded,
            label: widget.expanded ? 'Tutup bagian' : 'Buka bagian',
            child: InkWell(
              onTap: () { triggerHaptic(HapticType.selection); widget.onToggle?.call(); },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: widget.headerPadding,
                child: Row(
                  children: [
                    Expanded(child: widget.header),
                    const SizedBox(width: 8),
                    RotationTransition(
                      turns: _turns,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.colors.textMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showContent) ...[
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                child: SizeTransition(
                  sizeFactor: _sizeFactor,
                  child: widget.content,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
