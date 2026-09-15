/// Resolusi deep-link notifikasi → route go_router internal.
///
/// Dipakai bersama oleh handler push FCM (`notification_handler.dart`) dan
/// daftar riwayat in-app (`features/notifikasi/notifikasi_screen.dart`) supaya
/// tap notifikasi selalu menavigasi ke layar terkait **di dalam app** — tidak
/// keluar ke browser eksternal.
library;

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
