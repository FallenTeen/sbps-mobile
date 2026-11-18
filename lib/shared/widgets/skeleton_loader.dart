import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_spacing.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final defaultBase = isDark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerHighest;
    final defaultHighlight = isDark
        ? scheme.surfaceContainerHighest
        : scheme.surfaceContainerLow;

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
        borderRadius: shape == BoxShape.circle
            ? null
            : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Pre-sized skeleton blocks using spacing tokens.
class SkeletonBlocks {
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 48;
  static const double badge = 20;
  static const double lineSm = 11;
  static const double lineMd = 14;
  static const double lineLg = 16;
  static const double card = 100;
  static const double cardLg = 160;
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
      margin: AppSpacing.onlyBottomXs,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hasLeading) ...[
              const SkeletonBlock(
                width: SkeletonBlocks.avatarMd,
                height: SkeletonBlocks.avatarMd,
                shape: BoxShape.circle,
              ),
              AppSpacing.hGapMd,
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SkeletonBlock(width: double.infinity, height: SkeletonBlocks.lineMd),
                  if (hasSubtitle) ...[
                    AppSpacing.vGapXs,
                    const SkeletonBlock(width: 140, height: SkeletonBlocks.lineSm),
                  ],
                ],
              ),
            ),
            if (hasTrailing) ...[
              AppSpacing.hGapMd,
              const SkeletonBlock(width: 48, height: SkeletonBlocks.badge, borderRadius: 12),
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
    this.margin = const EdgeInsets.only(bottom: 8),
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
        child: Padding(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBlock(width: 160, height: SkeletonBlocks.lineLg),
              AppSpacing.vGapSm,
              SkeletonBlock(width: double.infinity, height: SkeletonBlocks.lineSm),
              AppSpacing.vGapXs,
              SkeletonBlock(width: 220, height: SkeletonBlocks.lineSm),
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
        padding: AppSpacing.paddingMd,
        children: [
          SkeletonCard(height: 110),
          AppSpacing.vGapXs,
          SkeletonCard(height: 160),
          AppSpacing.vGapXs,
          SkeletonCard(height: 140),
        ],
      ),
    );
  }
}

/// Skeleton untuk Dashboard Overview
class SkeletonDashboardOverview extends StatelessWidget {
  const SkeletonDashboardOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonCard(height: 90),
          AppSpacing.vGapSm,
          Row(
            children: [
              Expanded(child: SkeletonCard(height: 80)),
              AppSpacing.hGapXs,
              Expanded(child: SkeletonCard(height: 80)),
            ],
          ),
          AppSpacing.vGapSm,
          SkeletonCard(height: 180),
        ],
      ),
    );
  }
}

/// Skeleton khusus area chart - tinggi tetap [height] (default 180dp, sesuai
/// tinggi spesifikasi chart) supaya tidak ada layout-shift saat data sedang
/// di-fetch. Bentuk placeholder: batang-batang berdiri seperti bar chart.
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key, this.height = 180});

  final double height;

  static const _fractions = <double>[0.5, 0.72, 0.44, 0.86, 0.6, 0.9, 0.55];

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final f in _fractions)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FractionallySizedBox(
                    heightFactor: f,
                    alignment: Alignment.bottomCenter,
                    child: const SkeletonBlock(
                      width: double.infinity,
                      height: double.infinity,
                      borderRadius: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
