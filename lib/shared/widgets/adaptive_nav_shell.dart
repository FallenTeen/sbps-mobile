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
    this.activeRole,
  });

  /// Pane konten aktif, biasanya `StatefulNavigationShell` dari GoRouter.
  final Widget child;

  /// Indeks destinasi yang sedang aktif (0-based di dalam [destinations]).
  final int currentIndex;

  /// Dipanggil saat user mengetuk destinasi lain.
  final ValueChanged<int> onDestinationSelected;

  final List<AdaptiveNavDestination> destinations;

  /// Role aktif — bila diisi, strip "Bekerja sebagai: …" ditampilkan
  /// persisten di atas konten (perbaikan Phase 18). Nilai null (mis. layar
  /// presensi-only) tidak menampilkan strip.
  final String? activeRole;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return child;

    final screenClass = context.screenClass;
    final activeRole = this.activeRole;
    final roleBar = activeRole == null ? null : _ActiveRoleBar(role: activeRole);
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
          body: Column(
            children: [
              ?roleBar,
              Expanded(
                child: Row(
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
              ),
            ],
          ),
        );
      case ScreenClass.medium:
        return Scaffold(
          body: Column(
            children: [
              ?roleBar,
              Expanded(
                child: Row(
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
              ),
            ],
          ),
        );
      case ScreenClass.compact:
        return Scaffold(
          body: Column(
            children: [
              ?roleBar,
              Expanded(child: child),
            ],
          ),
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

/// Strip tipis yang menampilkan role aktif ("Bekerja sebagai: …") secara
/// persisten di atas konten — perbaikan Phase 18.
class _ActiveRoleBar extends StatelessWidget {
  const _ActiveRoleBar({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge_outlined, size: 14, color: scheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Bekerja sebagai: $role',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
