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

  /// Identitas destinasi ('home', 'produksi', 'qc', …) - dipakai router untuk
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
/// dirender sama sekali - cukup tampilkan [child] polos.
class AdaptiveNavShell extends StatelessWidget {
  const AdaptiveNavShell({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.activeRole,
    this.notifikasiBadgeCount = 0,
  });

  /// Pane konten aktif, biasanya `StatefulNavigationShell` dari GoRouter.
  final Widget child;

  /// Indeks destinasi yang sedang aktif (0-based di dalam [destinations]).
  /// Null jika rute aktif saat ini berada di luar destinasi utama shell.
  final int? currentIndex;

  /// Dipanggil saat user mengetuk destinasi lain.
  final ValueChanged<int> onDestinationSelected;

  final List<AdaptiveNavDestination> destinations;

  /// Role aktif - bila diisi, strip "Bekerja sebagai: …" ditampilkan
  /// persisten di atas konten. Nilai null (mis. layar
  /// presensi-only) tidak menampilkan strip.
  final String? activeRole;

  /// Jumlah notifikasi belum dibaca - tampil sebagai badge pada destinasi
  /// `notifikasi` (tab persisten menjadi satu-satunya pintu notifikasi di
  /// dalam shell; bel AppBar dihapus dari kluster aksi).
  final int notifikasiBadgeCount;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) return child;

    final screenClass = context.screenClass;
    final activeRole = this.activeRole;
    final roleBar = activeRole == null ? null : _ActiveRoleBar(role: activeRole);
    final railDestinations = [
      for (final d in destinations)
        NavigationRailDestination(
          icon: _destinationIcon(context, d),
          selectedIcon: _destinationIcon(context, d, selected: true),
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
          bottomNavigationBar: currentIndex == null
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex!,
                  onDestinationSelected: onDestinationSelected,
                  destinations: [
                    for (final d in destinations)
                      NavigationDestination(
                        icon: _destinationIcon(context, d),
                        selectedIcon: _destinationIcon(context, d, selected: true),
                        label: d.label,
                      ),
                  ],
                ),
        );
    }
  }

  /// Ikon destinasi; destinasi `notifikasi` membungkus badge jumlah belum
  /// dibaca sehingga indikator tetap terlihat tanpa bel AppBar tambahan.
  Widget _destinationIcon(
    BuildContext context,
    AdaptiveNavDestination d, {
    bool selected = false,
  }) {
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    if (d.key != 'notifikasi' || notifikasiBadgeCount <= 0) return icon;
    return Badge(
      isLabelVisible: true,
      label: Text(notifikasiBadgeCount > 99 ? '99+' : '$notifikasiBadgeCount'),
      child: icon,
    );
  }
}

/// Strip tipis yang menampilkan role aktif ("Bekerja sebagai: …") secara
/// persisten di atas konten.
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
