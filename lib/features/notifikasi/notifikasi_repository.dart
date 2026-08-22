import '../../core/api_client.dart';
import '../../core/api_response.dart';
import 'models/notification.dart';

/// Repository Notifikasi (docs/api-mobile.md §13).
class NotifikasiRepository {
  NotifikasiRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  /// Maks 50 notifikasi terbaru + jumlah belum dibaca.
  Future<NotificationsPage> getNotifications() async {
    final res = await _api.get<NotificationsPage>(
      '/notifications',
      parse: NotificationsPage.fromJson,
    );
    _ensureSuccess(res);
    return res.data ?? const NotificationsPage(items: [], unreadCount: 0);
  }

  /// Tandai satu notifikasi dibaca.
  Future<void> markRead(String id) async {
    final res = await _api.post('/notifications/$id/read');
    _ensureSuccess(res);
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}
