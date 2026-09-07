import 'package:flutter/material.dart';

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
  ProyekModule(
    key: 'armada',
    label: 'Armada',
    icon: Icons.local_shipping,
  ),
];

/// Permission matrix sisi client — HANYA lapisan UX untuk navigasi/guard
/// route. Validasi sesungguhnya tetap di backend (403 kalau ditembus
/// langsung). Catatan backend: guard "Admin" = `Owner` ATAU
/// `Admin Keuangan`, jadi keduanya mendapat akses penuh di sini.
class RolePermissions {
  const RolePermissions._();

  static const Map<String, Set<String>> _matrix = <String, Set<String>>{
    // Fase A2.6: Mandor Titik dapat overview + armada-status (non-finansial).
    'Mandor Titik': {'produksi', 'qc', 'tracking', 'dashboard'},
    'Kontraktor': {'dashboard'},
    'Owner': {'produksi', 'qc', 'tracking', 'dashboard', 'keuangan'},
    'Admin Keuangan': {'tracking', 'dashboard', 'keuangan'},
    'Driver Armada': {'armada'},
  };

  static Set<String> modulesFor(String? role) =>
      _matrix[role] ?? const <String>{};

  static bool canAccess(String? role, String moduleKey) =>
      modulesFor(role).contains(moduleKey);

  /// Setara guard "admin" backend: Owner ATAU Admin Keuangan.
  static bool isAdminLike(String? role) =>
      role == 'Owner' || role == 'Admin Keuangan';
}
