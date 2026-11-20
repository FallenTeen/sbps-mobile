import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'brand_strip.dart';

/// Kerangka halaman bersama: AppBar dengan identitas merek, search opsional,
/// dan konten yang dibatasi lebar maksimum lalu ditengahkan.
class AppScreenFrame extends StatelessWidget {
  const AppScreenFrame({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.search,
    required this.body,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? search;
  final Widget body;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      actions: actions,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: BrandStrip(),
      ),
    );

    final headerHeight =
        appBar.preferredSize.height + MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        SizedBox(height: headerHeight, child: appBar),
        if (search != null) search!,
        Expanded(
          child: ResponsiveCenter(
            maxWidth: maxWidth,
            padding: EdgeInsets.all(AppSpacing.md),
            child: body,
          ),
        ),
      ],
    );
  }
}
