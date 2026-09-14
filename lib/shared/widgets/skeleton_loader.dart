import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable skeleton loader with Shimmer effect for smooth initial loading states.
/// Designed to be lightweight and performant on mid-to-low tier mobile devices.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBase = isDark
        ? Colors.grey.shade800
        : Colors.grey.shade300;
    final defaultHighlight = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor ?? defaultBase,
      highlightColor: highlightColor ?? defaultHighlight,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Generic block with rounded corners for skeleton layouts.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 6.0,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton for ListTile-based items (Riwayat, Notifikasi, Titik kerja, etc.)
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({
    super.key,
    this.hasLeading = true,
    this.hasSubtitle = true,
    this.hasTrailing = true,
  });

  final bool hasLeading;
  final bool hasSubtitle;
  final bool hasTrailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasLeading) ...[
              const SkeletonBlock(
                width: 40,
                height: 40,
                shape: BoxShape.circle,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SkeletonBlock(width: double.infinity, height: 14),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 8),
                    const SkeletonBlock(width: 140, height: 11),
                  ],
                ],
              ),
            ),
            if (hasTrailing) ...[
              const SizedBox(width: 16),
              const SkeletonBlock(width: 48, height: 20, borderRadius: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton for a list of items (e.g. Riwayat screens, Notifikasi)
class SkeletonListView extends StatelessWidget {
  const SkeletonListView({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (_, _) => const SkeletonListTile(),
      ),
    );
  }
}

/// Skeleton for Cards (e.g. Header Presensi, Tracking status)
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.height = 100,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final double height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(width: 160, height: 16),
              SizedBox(height: 12),
              SkeletonBlock(width: double.infinity, height: 12),
              SizedBox(height: 8),
              SkeletonBlock(width: 220, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for Detail Screens (e.g. Detail Titik, Detail QC, Detail Servis)
class SkeletonDetailView extends StatelessWidget {
  const SkeletonDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SkeletonCard(height: 110),
          SizedBox(height: 8),
          SkeletonCard(height: 160),
          SizedBox(height: 8),
          SkeletonCard(height: 140),
        ],
      ),
    );
  }
}

/// Skeleton for Dashboard Overview
class SkeletonDashboardOverview extends StatelessWidget {
  const SkeletonDashboardOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonCard(height: 90),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: SkeletonCard(height: 80)),
              SizedBox(width: 8),
              Expanded(child: SkeletonCard(height: 80)),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonCard(height: 180),
        ],
      ),
    );
  }
}
