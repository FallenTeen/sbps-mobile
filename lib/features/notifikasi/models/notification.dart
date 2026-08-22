/// Satu notifikasi dari GET /notifications (docs/api-mobile.md §13).
class AppNotification {
  const AppNotification({
    required this.id,
    this.title,
    this.body,
    this.actionUrl,
    required this.isRead,
    this.time,
  });

  final String id;
  final String? title;
  final String? body;

  /// URL tujuan saat notifikasi di-tap (opsional).
  final String? actionUrl;
  final bool isRead;
  final String? time;

  static AppNotification fromJson(Object? raw) {
    if (raw is! Map) throw const FormatException('notifikasi tidak valid');
    final json = Map<String, dynamic>.from(raw);
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      body: json['body']?.toString(),
      actionUrl: json['action_url']?.toString(),
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
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}
