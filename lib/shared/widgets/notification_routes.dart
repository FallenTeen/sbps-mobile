/// Resolusi deep-link notifikasi → target navigasi go_router.
///
/// Dipakai bersama oleh handler push FCM (`notification_handler.dart`),
/// daftar riwayat in-app (`features/notifikasi/notifikasi_screen.dart`), dan
/// daftar aktivitas beranda (`features/dashboard/dashboard_home_screen.dart`)
/// supaya tap notifikasi **selalu** menuju layar yang relevan di dalam app —
/// dengan validasi route dikenali + hak akses role, dan pesan yang jelas
/// ketika tujuan tidak tersedia.
library;

import '../../core/app_router.dart';
import '../../features/notifikasi/models/notification.dart';
import '../../features/proyek/role_permissions.dart';

/// Status tujuan deep-link setelah resolusi [resolveNotificationDestination].
enum NotificationTargetStatus {
  /// Route internal valid & role boleh buka → push route.
  open,

  /// Tautan eksternal (bukan route internal) → buka via url_launcher.
  openExternal,

  /// Route valid tapi role aktif tidak punya akses modul → kasih tahu user.
  deniedRole,

  /// Tidak ada tautan/route yang dikenali → fallback layar Notifikasi.
  unavailable,
}

/// Hasil resolusi deep-link.
///
/// [route] terisi untuk `open`/`deniedRole`; [externalUrl] untuk
/// `openExternal`. [actionable] berarti layar bisa langsung dibuka.
class ResolvedNotificationDestination {
  const ResolvedNotificationDestination({
    required this.status,
    this.route,
    this.externalUrl,
  });

  const ResolvedNotificationDestination.open(this.route)
    : status = NotificationTargetStatus.open,
      externalUrl = null;

  const ResolvedNotificationDestination.deniedRole(this.route)
    : status = NotificationTargetStatus.deniedRole,
      externalUrl = null;

  const ResolvedNotificationDestination.openExternal(this.externalUrl)
    : status = NotificationTargetStatus.openExternal,
      route = null;

  const ResolvedNotificationDestination.unavailable()
    : status = NotificationTargetStatus.unavailable,
      route = null,
      externalUrl = null;

  final NotificationTargetStatus status;
  final String? route;
  final String? externalUrl;

  bool get actionable => status == NotificationTargetStatus.open;
}

/// Pesan snackbar saat tujuan tidak (bisa) dibuka — null bila aman lanjut.
String? notificationDestinationMessage(ResolvedNotificationDestination d) {
  return switch (d.status) {
    NotificationTargetStatus.deniedRole =>
      'Role kamu tidak punya akses ke layar tersebut.',
    NotificationTargetStatus.unavailable =>
      'Layar terkait belum tersedia.',
    _ => null,
  };
}

/// Prefix modul → kunci permission (paralel dengan _matrix RolePermissions).
const _moduleRoutePrefixes = <String, String>{
  '/armada': 'armada',
  '/workshop': 'workshop',
  '/inventory': 'inventory',
  '/qc': 'qc',
  '/produksi': 'produksi',
  '/dashboard': 'dashboard',
  '/kontraktor': 'kontraktor',
  '/dokumentasi': 'produksi',
};

/// Area finansial khusus Owner / Admin Keuangan (paralel guard router).
const _financialPrefixes = <String>[
  '/dashboard/keuangan',
  '/dashboard/po-pending',
  '/dashboard/invoice',
];

/// Route universal — semua role boleh buka.
const _universalRoutes = <String>{
  '/home',
  '/proyek-home',
  '/presensi',
  '/presensi/riwayat',
  '/notifikasi',
  '/formulir',
  '/profile',
  '/data-belum-terkirim',
  '/portal',
  '/login',
  '/register',
};

/// Pola regex per path di [kAppRoutePaths]: segmen `:param` → `[^/]+`.
final List<RegExp> _routePatterns = [
  for (final path in kAppRoutePaths) _patternFor(path),
];

RegExp _patternFor(String path) {
  final escaped = path.replaceAll(RegExp(r'/:([A-Za-z0-9_]+)'), r'/[^/]+');
  return RegExp('^$escaped\$');
}

/// Apakah `path` (tanpa query) dikenali sebagai route app?
bool isKnownNotificationRoute(String path) {
  final candidate = path.split('?').first.trim();
  if (!candidate.startsWith('/')) return false;
  return _routePatterns.any((p) => p.hasMatch(candidate));
}

/// Bolehkah `role` membuka route `path`? Guard sisi client — backend tetap
/// validator utama. Role `null` (cold-start FCM sebelum auth pulih) diasumsikan
/// boleh: guard router-lah yang menegakkan.
bool roleCanOpenRoute(String? role, String path) {
  final candidate = path.split('?').first.trim();
  if (role == null) return true;

  if (candidate.startsWith('/tracking')) {
    return RolePermissions.isAdminLike(role);
  }
  if (_financialPrefixes.any(candidate.startsWith)) {
    return RolePermissions.isAdminLike(role);
  }
  for (final entry in _moduleRoutePrefixes.entries) {
    if (candidate == entry.key || candidate.startsWith('${entry.key}/')) {
      return RolePermissions.canAccess(role, entry.value);
    }
  }
  return _universalRoutes.contains(candidate);
}

/// Resolusi deep-link satu notifikasi.
///
/// Prioritas:
/// 1. `actionUrl` internal (`/...`) yang dikenali → dipakai langsung.
/// 2. `actionUrl` eksternal (punya skema) → `openExternal`.
/// 3. `route` + `routeId` dari backend → digabung & divalidasi.
/// 4. selain itu → `unavailable`.
ResolvedNotificationDestination resolveNotificationDestination({
  required AppNotification notification,
  required String? role,
}) {
  final actionUrl = notification.actionUrl?.trim();
  if (actionUrl != null && actionUrl.isNotEmpty) {
    if (actionUrl.startsWith('/')) {
      if (isKnownNotificationRoute(actionUrl)) {
        return _roleGate(role, actionUrl);
      }
    } else if (_isAbsoluteUrl(actionUrl)) {
      return ResolvedNotificationDestination.openExternal(actionUrl);
    }
  }

  final baseRoute = notification.route?.trim();
  if (baseRoute != null && baseRoute.isNotEmpty) {
    final target = fcmNotificationRoute(baseRoute, notification.routeId);
    if (target != null && isKnownNotificationRoute(target)) {
      return _roleGate(role, target);
    }
  }

  return const ResolvedNotificationDestination.unavailable();
}

ResolvedNotificationDestination _roleGate(String? role, String path) {
  if (roleCanOpenRoute(role, path)) {
    return ResolvedNotificationDestination.open(path);
  }
  return ResolvedNotificationDestination.deniedRole(path);
}

bool _isAbsoluteUrl(String url) => Uri.tryParse(url)?.hasScheme ?? false;

/// Konversi `actionUrl` item notifikasi (dari server) menjadi route internal.
///
/// Mengembalikan path go_router (diawali `/`, mis. `/armada/servis/123`) bila
/// tautan bersifat internal, atau `null` bila bukan tautan dalam app (mis.
/// `https://...` eksternal — harus dibuka lewat `url_launcher`).
String? notificationActionRoute(String? actionUrl) {
  final url = actionUrl?.trim();
  if (url == null || url.isEmpty) return null;
  if (!url.startsWith('/')) return null;
  return url;
}

/// Route dari payload push FCM (`route` + opsional `id`) — pola yang
/// dipakai `notification_handler.dart`. `route="/armada/servis"` + `id="123"`
/// → `/armada/servis/123`. Terpisah dari [notificationActionRoute] karena
/// payload FCM menyandang `route` dan `id` sebagai field terpisah.
String? fcmNotificationRoute(String? route, String? id) {
  final path = route?.trim();
  if (path == null || path.isEmpty) return null;
  if (!path.startsWith('/')) return null;
  final routeId = id?.trim();
  if (routeId == null || routeId.isEmpty) return path;
  return path.endsWith('/') ? '$path$routeId' : '$path/$routeId';
}