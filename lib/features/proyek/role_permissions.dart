import 'package:flutter/material.dart';

import '../../shared/theme/app_icons.dart';
import '../../shared/widgets/adaptive_nav_shell.dart';

/// Katalog modul App 2 yang tampil sebagai tile di home; visibilitas
/// ditentukan [RolePermissions] sesuai role aktif.
class ProyekModule {
  const ProyekModule({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

const kProyekModules = <ProyekModule>[
  ProyekModule(
    key: 'produksi',
    label: 'Produksi',
    icon: Icons.precision_manufacturing,
  ),
  ProyekModule(key: 'qc', label: 'Quality Control', icon: Icons.fact_check),
  ProyekModule(key: 'tracking', label: 'Tracking', icon: Icons.local_shipping),
  ProyekModule(
    key: 'dashboard',
    label: 'Dashboard Operasional',
    icon: Icons.dashboard_outlined,
  ),
  ProyekModule(
    key: 'keuangan',
    label: 'Dashboard Finansial',
    icon: Icons.payments_outlined,
  ),
  ProyekModule(key: 'armada', label: 'Armada', icon: Icons.local_shipping),
  ProyekModule(
    key: 'kontraktor',
    label: 'Portal Kontrak',
    icon: Icons.business_center_outlined,
  ),
  ProyekModule(key: 'workshop', label: 'Workshop', icon: Icons.build_rounded),
  ProyekModule(
    key: 'inventory',
    label: 'Inventory',
    icon: Icons.inventory_2_outlined,
  ),
];

/// Permission matrix sisi client — HANYA lapisan UX untuk navigasi/guard
/// route. Validasi sesungguhnya tetap di backend (403 kalau ditembus
/// langsung). Catatan backend: guard "Admin" = `Owner` ATAU
/// `Admin Keuangan`, jadi keduanya mendapat akses penuh di sini.
class RolePermissions {
  const RolePermissions._();

  static const Map<String, Set<String>> _matrix = <String, Set<String>>{
    'Mandor Titik': {'produksi', 'qc', 'tracking', 'dashboard'},
    'Kontraktor': {'dashboard', 'kontraktor'},
    'Owner': {
      'produksi',
      'qc',
      'tracking',
      'dashboard',
      'keuangan',
      'armada',
      'kontraktor',
      'workshop',
      'inventory',
    },
    'Admin Keuangan': {
      'tracking',
      'dashboard',
      'keuangan',
      'armada',
      'kontraktor',
    },
    'Driver Armada': {'armada'},
    'Kepala Divisi Armada': {'armada', 'dashboard'},
    'Workshop': {'workshop'},
    'Inventory': {'inventory'},
  };

  static Set<String> modulesFor(String? role) =>
      _matrix[role] ?? const <String>{};

  static bool canAccess(String? role, String moduleKey) =>
      modulesFor(role).contains(moduleKey);

  /// Setara guard "admin" backend: Owner ATAU Admin Keuangan.
  static bool isAdminLike(String? role) =>
      role == 'Owner' || role == 'Admin Keuangan';
}

/// Path root tiap modul di dalam shell — dipakai router untuk memetakan
/// destinasi nav ke branch `StatefulShellRoute`.
const kModuleRouteRoots = <String, String>{
  'produksi': '/produksi/sesi-aktif',
  'qc': '/qc/riwayat',
  'tracking': '/tracking/pengguna-aktif',
  'dashboard': '/dashboard',
  'keuangan': '/dashboard/keuangan',
  'armada': '/armada',
  'kontraktor': '/kontraktor/proyek',
  'workshop': '/workshop',
  'inventory': '/inventory',
};

/// Urutan prioritas modul per role untuk destinasi utama nav shell
/// (dari referensi Bagian 3 dokumentasi — modul paling sering dipakai dulu).
const _navModuleOrder = <String, List<String>>{
  'Mandor Titik': ['produksi', 'qc', 'dashboard', 'tracking'],
  'Owner': ['produksi', 'armada', 'dashboard', 'keuangan'],
  'Admin Keuangan': ['dashboard', 'keuangan', 'armada', 'kontraktor'],
  'Kepala Divisi Armada': ['armada', 'dashboard'],
  'Kontraktor': ['kontraktor', 'dashboard'],
  'Workshop': ['workshop'],
  'Inventory': ['inventory'],
  'Driver Armada': ['armada'],
};

AdaptiveNavDestination _homeDestination() => const AdaptiveNavDestination(
  key: 'home',
  label: 'Beranda',
  icon: AppIcons.navHome,
  selectedIcon: AppIcons.navHomeActive,
);

AdaptiveNavDestination _moduleDestination(String key) {
  final module = kProyekModules.firstWhere((m) => m.key == key);
  return AdaptiveNavDestination(
    key: module.key,
    label: module.label,
    icon: module.icon,
    selectedIcon: module.icon,
  );
}

/// Destinasi nav shell untuk role tertentu: "Beranda" (module cards penuh)
/// + maksimal 4 modul paling sering dipakai (total ≤5, batas Material
/// `NavigationBar`). Role dengan ≤1 modul akses (mis. Driver Armada)
/// mengembalikan list kosong → `AdaptiveNavShell` tidak dirender.
List<AdaptiveNavDestination> buildNavDestinations(String? role) {
  final allowed = RolePermissions.modulesFor(role);
  if (allowed.length <= 1) return const [];

  final pick = <String>[];
  for (final key in _navModuleOrder[role] ?? const <String>[]) {
    if (allowed.contains(key) && !pick.contains(key)) pick.add(key);
    if (pick.length >= 4) break;
  }
  for (final key in allowed) {
    if (!pick.contains(key)) pick.add(key);
    if (pick.length >= 4) break;
  }

  return [_homeDestination(), for (final key in pick) _moduleDestination(key)];
}
