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
    'Ketua Divisi Armada': {'armada', 'dashboard'},
    'Ketua Armada': {'armada', 'dashboard'},
    'Workshop': {'workshop'},
    'Inventory': {'inventory'},
    'Operator Mesin': {'produksi', 'qc'},
  };

  static Set<String> modulesFor(String? role) =>
      _matrix[role] ?? const <String>{};

  static bool canAccess(String? role, String moduleKey) =>
      modulesFor(role).contains(moduleKey);

  /// Setara guard "admin" backend: Owner ATAU Admin Keuangan.
  static bool isAdminLike(String? role) =>
      role == 'Owner' || role == 'Admin Keuangan';
}

AdaptiveNavDestination _homeDestination() => const AdaptiveNavDestination(
  key: 'home',
  label: 'Beranda',
  icon: AppIcons.navHome,
  selectedIcon: AppIcons.navHomeActive,
);

/// Tab "Presensi" — universal untuk semua role (tiap karyawan wajib absen,
/// termasuk Driver Armada, Workshop, Inventory, dan role manajemen).
AdaptiveNavDestination _presensiDestination() => const AdaptiveNavDestination(
  key: 'presensi',
  label: 'Presensi',
  icon: Icons.fingerprint,
  selectedIcon: Icons.fingerprint_rounded,
);

AdaptiveNavDestination _notifikasiDestination() => const AdaptiveNavDestination(
  key: 'notifikasi',
  label: 'Notifikasi',
  icon: Icons.notifications_outlined,
  selectedIcon: Icons.notifications_rounded,
);

AdaptiveNavDestination _tugasDestination() => const AdaptiveNavDestination(
  key: 'tugas',
  label: 'Tugas / Operasional',
  icon: Icons.assignment_outlined,
  selectedIcon: Icons.assignment_rounded,
);

/// Branch indeks di dalam shell tunggal SBPS Mobile untuk tab Presensi dan
/// Notifikasi (branch 10 & 11 — see [navBranchFor]).
const kPresensiBranchIndex = 10;
const kNotifikasiBranchIndex = 11;

/// Modul yang menjadi isi tab "Tugas / Operasional" per role multi-modul.
/// Field role (Driver/Workshop/Inventory) tidak ada di sini: Beranda mereka
/// sudah langsung pekerjaan hari ini, jadi tab Tugas tidak perlu dirender.
const _tugasModuleByRole = <String, String>{
  'Mandor Titik': 'produksi',
  'Owner': 'dashboard',
  'Admin Keuangan': 'keuangan',
  'Kepala Divisi Armada': 'armada',
  'Ketua Divisi Armada': 'armada',
  'Ketua Armada': 'armada',
  'Kontraktor': 'kontraktor',
  'Operator Mesin': 'produksi',
};

/// Modul utama untuk tab "Tugas / Operasional" (null = tidak ada).
String? tugasModuleFor(String? role) => _tugasModuleByRole[role];

/// Jenis isi Beranda (role-aware).
enum AppHomeKind { presensi, driver, workshop, inventory, proyek }

/// Mapping role + portal → isi Beranda.
///
/// - Portal Presensi (atau tanpa role App 2) → beranda presensi.
/// - Driver Armada → "Pekerjaan Hari Ini" (Unit Saya / workflow).
/// - Workshop → "Workshop Hari Ini" (antrian).
/// - Inventory → "Perhatian Hari Ini" (stok rendah / request / opname).
/// - Role lain (Mandor/Owner/Admin/Kontraktor/Kepala Divisi) → module cards
///   penuh ([ProyekHomeScreen]) — attention + operational + modul.
AppHomeKind appHomeKindFor({required String? role, required bool presensiPortal}) {
  if (presensiPortal || role == null) return AppHomeKind.presensi;
  return switch (role) {
    'Driver Armada' => AppHomeKind.driver,
    'Workshop' => AppHomeKind.workshop,
    'Inventory' => AppHomeKind.inventory,
    _ => AppHomeKind.proyek,
  };
}

/// Branch index StatefulShellRoute untuk sebuah key destinasi navigasi.
///
/// [moduleBranchByKey] = peta key modul → branch shell (definisi di router,
/// `_proyekBranchByModule`). Tab universal (`home`/`presensi`/`notifikasi`)
/// dan `tugas` (yang menunjuk modul utama role) diresolusi di sini sehingga
/// mapping destinasi → branch bisa diuji tanpa perlu GoRouter.
int navBranchFor(
  String destinationKey,
  String? role,
  Map<String, int> moduleBranchByKey,
) {
  switch (destinationKey) {
    case 'home':
      return 0;
    case 'presensi':
      return kPresensiBranchIndex;
    case 'notifikasi':
      return kNotifikasiBranchIndex;
    case 'tugas':
      final module = tugasModuleFor(role);
      return module == null ? 0 : (moduleBranchByKey[module] ?? 0);
    default:
      return moduleBranchByKey[destinationKey] ?? 0;
  }
}

/// Destinasi nav shell role-aware (maksimal 4, sesuai rencana §5: Beranda,
/// Tugas/Operasional, Presensi, Notifikasi). Field single-modul hanya
/// Beranda + Presensi + Notifikasi (Beranda mereka sudah merupakan pekerjaan).
/// Role tanpa akses modul (presensi-only) → Beranda + Notifikasi.
List<AdaptiveNavDestination> buildNavDestinations(String? role) {
  final allowed = RolePermissions.modulesFor(role);
  final destination = <AdaptiveNavDestination>[_homeDestination()];

  final tugasModule = tugasModuleFor(role);
  if (tugasModule != null && allowed.contains(tugasModule)) {
    destination.add(_tugasDestination());
  }
  if (allowed.isNotEmpty) {
    destination.add(_presensiDestination());
  }
  destination.add(_notifikasiDestination());
  return destination;
}
