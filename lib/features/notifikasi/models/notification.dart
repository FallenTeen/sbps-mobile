import '../../../core/json_num.dart';

/// Kategori notifikasi (Phase 16 action center). Dikirim server via field
/// `category`; nilai tak dikenal di-parse sebagai [NotificationCategory.sistem].
///
/// Murni Dart (tanpa import Flutter) supaya bisa diuji sebagai unit test.
enum NotificationCategory {
  approval('approval', 'Approval'),
  servis('servis', 'Servis'),
  stok('stok', 'Stok'),
  produksi('produksi', 'Produksi'),
  presensi('presensi', 'Presensi'),
  formulir('formulir', 'Formulir'),
  sistem('sistem', 'Sistem');

  const NotificationCategory(this.value, this.label);

  /// Nilai wire (JSON) dari backend.
  final String value;

  /// Label untuk tampilan (chip filter & tile).
  final String label;

  /// Parser backward-compatible: null / tak dikenal → sistem.
  static NotificationCategory parse(Object? raw) {
    final v = raw?.toString().trim().toLowerCase();
    for (final c in NotificationCategory.values) {
      if (c.value == v) return c;
    }
    return NotificationCategory.sistem;
  }
}

/// Satu notifikasi dari GET /notifications (docs/api-mobile.md § Notifikasi).
class AppNotification {
  const AppNotification({
    required this.id,
    this.title,
    this.body,
    this.actionUrl,
    this.category = NotificationCategory.sistem,
    this.type,
    this.route,
    this.routeId,
    required this.isRead,
    this.time,
  });

  /// Id NOTIFIKASI (basis markRead).
  final String id;
  final String? title;
  final String? body;

  /// URL/target aksi saat notifikasi di-tap (opsional).
  final String? actionUrl;

  /// Kategori action center (Phase 16).
  final NotificationCategory category;

  /// Nama class notifikasi backend (informasi; mis. `MobileNotification`).
  final String? type;

  /// Base route internal go_router tujuan deep-link (mis. `/armada/servis`).
  final String? route;

  /// Id record tujuan — path parameter route (mis. `123` / UUID / `po_2`).
  final String? routeId;
  final bool isRead;
  final String? time;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    actionUrl: actionUrl,
    category: category,
    type: type,
    route: route,
    routeId: routeId,
    isRead: isRead ?? this.isRead,
    time: time,
  );

  static AppNotification fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('notifikasi tidak valid');
    final json = Map<String, dynamic>.from(raw);
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      actionUrl: json['action_url']?.toString(),
      category: NotificationCategory.parse(json['category']),
      type: json['type']?.toString(),
      route: json['route']?.toString(),
      routeId: json['route_id']?.toString(),
      isRead: json['is_read'] == true,
      time: json['time']?.toString(),
    );
  }
}

/// Envelope `data` GET /notifications.
class NotificationsPage {
  const NotificationsPage({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;

  static NotificationsPage fromJson(Object? raw) {
    if (raw is! Map) {
      return const NotificationsPage(items: [], unreadCount: 0);
    }
    final json = Map<String, dynamic>.from(raw);
    final itemsRaw = json['notifications'];
    return NotificationsPage(
      items: itemsRaw is List
          ? itemsRaw.map(AppNotification.fromJson).toList()
          : [],
      unreadCount: parseInt(json['unread_count']) ?? 0,
    );
  }
}