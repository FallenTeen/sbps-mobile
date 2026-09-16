import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ikon info kecil di sebelah label field.
/// Tap untuk munculkan penjelasan singkat (Tooltip) atau bottom sheet (untuk teks panjang).
class InfoTooltip extends StatelessWidget {
  const InfoTooltip({
    super.key,
    required this.message,
    this.title,
    this.maxLength = 80,
  });

  final String message;
  final String? title;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final useSheet = message.length > maxLength;

    return Semantics(
      button: true,
      tooltip: message,
      child: GestureDetector(
        onTap: () {
          if (useSheet) {
            _showBottomSheet(context);
          } else {
            _showTooltip(context);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: Theme.of(
                context,
              ).textTheme.labelMedium?.color ?? context.colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }

  void _showTooltip(BuildContext context) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final target = renderBox.localToGlobal(renderBox.size.center(Offset.zero));

    final entry = OverlayEntry(
      builder: (_) => _TooltipOverlay(target: target, message: message),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => entry.remove());
  }

  void _showBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.bottomSheetTheme.dragHandleColor ??
                      theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(
                title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TooltipOverlay extends StatefulWidget {
  const _TooltipOverlay({required this.target, required this.message});

  final Offset target;
  final String message;

  @override
  State<_TooltipOverlay> createState() => _TooltipOverlayState();
}

class _TooltipOverlayState extends State<_TooltipOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.inverseSurface;
    final onSurface = theme.colorScheme.onInverseSurface;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _controller.reverse().then((_) {
              // Overlay removed externally
            }),
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          left: widget.target.dx - 10,
          top: widget.target.dy - 44,
          child: FadeTransition(
            opacity: _opacity,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.message,
                  style: TextStyle(color: onSurface, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Row helper: label + optional InfoTooltip in a horizontal layout.
/// Digunakan di form fields untuk menyampingkan tooltip di sebelah label.
class LabelWithInfo extends StatelessWidget {
  const LabelWithInfo({
    super.key,
    required this.label,
    this.infoMessage,
    this.infoTitle,
    this.style,
  });

  final String label;
  final String? infoMessage;
  final String? infoTitle;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: style),
        if (infoMessage != null) ...[
          const SizedBox(width: 4),
          InfoTooltip(message: infoMessage!, title: infoTitle),
        ],
      ],
    );
  }
}
