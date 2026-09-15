import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/breakpoints.dart';

/// Destinasi navigasi persisten di dalam [AdaptiveNavShell].
class AdaptiveNavDestination {
  const AdaptiveNavDestination({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// Identitas destinasi ('home', 'produksi', 'qc', …) — dipakai router untuk
  /// memetakan destinasi ke branch `StatefulShellRoute`.
  final String key;

  final String label;

  /// Ikon kondisi tidak aktif.
  final IconData icon;

  /// Ikon kondisi aktif.
  final IconData selectedIcon;
}

/// Nav shell persisten role-aware untuk Portal Proyek.
///
/// Render mengikuti `context.screenClass` (helper yang sudah ada):
/// - Compact (<600dp): `NavigationBar` Material 3 di bagian bawah.
/// - Medium (600–839dp): `NavigationRail` di kiri, label hanya item terpilih.
/// - Expanded (≥840dp): `NavigationRail` extended di kiri, label selalu tampil.
///
/// Jika [destinations] kosong (mis. role hanya punya 1 modul), shell tidak
/// dirender sama sekali — cukup tampilkan [child] polos.
class AdaptiveNavShell extends StatelessWidget {
  const AdaptiveNavShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  /// Pane konten aktif, biasanya `StatefulNavigationShell` dari GoRouter.
  final Widget child;

  /// Indeks destinasi yang sedang aktif (0-based di dalam [destinations]).
  final int currentIndex;

  /// Dipanggil saat user mengetuk destinasi lain.
  final ValueChanged<int> onDestinationSelected;

  final List<AdaptiveNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return child;

    final screenClass = context.screenClass;
    final railDestinations = [
      for (final d in destinations)
        NavigationRailDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.selectedIcon),
          label: Text(d.label),
        ),
    ];

    switch (screenClass) {
      case ScreenClass.expanded:
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                extended: true,
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: railDestinations,
              ),
              VerticalDivider(width: 1, color: context.colors.border),
              Expanded(child: child),
            ],
          ),
        );
      case ScreenClass.medium:
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                labelType: NavigationRailLabelType.selected,
                selectedIndex: currentIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: railDestinations,
              ),
              VerticalDivider(width: 1, color: context.colors.border),
              Expanded(child: child),
            ],
          ),
        );
      case ScreenClass.compact:
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );
    }
  }
}
