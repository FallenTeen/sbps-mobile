import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import '../../core/analytics_service.dart';
import '../auth/models/user.dart';

const _kPortalBox = 'portal';
const _kSelectedPortal = 'selected_portal';

/// Portal type: presensi atau proyek.
enum AppPortal {
  presensi('Presensi', 'Presensi & kehadiran'),
  proyek('Proyek', 'Operasional & proyek');

  const AppPortal(this.label, this.description);
  final String label;
  final String description;
}

/// Box Hive untuk menyimpan portal selection.
Future<Box<String>> _openBox() async {
  if (Hive.isBoxOpen(_kPortalBox)) return Hive.box<String>(_kPortalBox);
  return Hive.openBox<String>(_kPortalBox);
}

/// Portal yang sedang dipilih user (null = belum pilih).
final selectedPortalProvider =
    AsyncNotifierProvider<SelectedPortalNotifier, AppPortal?>(
        SelectedPortalNotifier.new);

class SelectedPortalNotifier extends AsyncNotifier<AppPortal?> {
  @override
  Future<AppPortal?> build() async {
    final box = await _openBox();
    final saved = box.get(_kSelectedPortal);
    if (saved == null) return null;
    return AppPortal.values.firstWhere(
      (p) => p.name == saved,
      orElse: () => AppPortal.presensi,
    );
  }

  Future<void> select(AppPortal portal) async {
    final box = await _openBox();
    await box.put(_kSelectedPortal, portal.name);
    state = AsyncData(portal);
    AnalyticsService.setPortal(portal.name);
  }

  Future<void> clear() async {
    final box = await _openBox();
    await box.delete(_kSelectedPortal);
    state = const AsyncData(null);
  }
}

/// Role yang relevan untuk portal presensi.
const kPresensiRoles = <String>[
  'Mandor Titik',
  'SDM Lapangan Kondisional',
];

/// Role yang relevan untuk portal proyek.
const kProyekRoles = <String>[
  'Mandor Titik',
  'Kontraktor',
  'Owner',
  'Admin Keuangan',
  'Driver Armada',
  'Workshop',
  'Inventory',
];

/// Cek apakah user bisa mengakses portal presensi.
bool canAccessPresensi(User user) =>
    user.roles.any(kPresensiRoles.contains);

/// Cek apakah user bisa mengakses portal proyek.
bool canAccessProyek(User user) =>
    user.roles.any(kProyekRoles.contains);

/// Jika user hanya bisa akses 1 portal, return portal itu. Jika bisa 2,
/// return null (perlu pilih manual). Jika 0, return null.
AppPortal? autoPortal(User user) {
  final canPresensi = canAccessPresensi(user);
  final canProyek = canAccessProyek(user);
  if (canPresensi && !canProyek) return AppPortal.presensi;
  if (!canPresensi && canProyek) return AppPortal.proyek;
  return null;
}
