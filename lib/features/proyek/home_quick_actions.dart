import '../../shared/utils/module_routes.dart';
import 'role_permissions.dart';

const _quickActionKeysByRole = <String, List<String>>{
  'Owner': ['keuangan', 'dashboard', 'armada'],
  'Admin Keuangan': ['keuangan', 'dashboard', 'tracking'],
  'Kontraktor': ['kontraktor', 'dashboard'],
  'Mandor Proyek': ['produksi', 'qc'],
};

List<String> homeQuickActionKeysForRole(String? role) {
  final preferred = _quickActionKeysByRole[role] ?? const <String>[];
  return preferred
      .where(
        (key) =>
            RolePermissions.canAccess(role, key) &&
            moduleRouteFor(key) != null,
      )
      .take(3)
      .toList();
}
