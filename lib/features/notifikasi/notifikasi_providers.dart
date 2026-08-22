import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../auth/auth_providers.dart';
import 'models/notification.dart';
import 'notifikasi_repository.dart';

final notifikasiRepositoryProvider = Provider<NotifikasiRepository>(
  (ref) => NotifikasiRepository(api: ref.watch(apiClientProvider)),
);

/// Daftar notifikasi (maks 50 terbaru) + unread count.
class NotificationsController extends AsyncNotifier<NotificationsPage> {
  @override
  Future<NotificationsPage> build() =>
      ref.read(notifikasiRepositoryProvider).getNotifications();

  Future<void> refresh() async {
    try {
      final page =
          await ref.read(notifikasiRepositoryProvider).getNotifications();
      state = AsyncData(page);
      ref.read(unreadCountProvider.notifier).set(page.unreadCount);
    } on ApiException catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  /// Tandai satu notifikasi dibaca: panggil server, lalu perbarui list &
  /// badge secara optimis. Mengembalikan pesan error bila gagal.
  Future<String?> markRead(AppNotification notification) async {
    if (notification.isRead) return null;
    try {
      await ref
          .read(notifikasiRepositoryProvider)
          .markRead(notification.id);
      final current = state.value;
      if (current != null) {
        state = AsyncData(NotificationsPage(
          items: current.items
              .map((n) => n.id == notification.id ? _asRead(n) : n)
              .toList(),
          unreadCount: current.unreadCount > 0
              ? current.unreadCount - 1
              : 0,
        ));
        ref
            .read(unreadCountProvider.notifier)
            .set(state.value!.unreadCount);
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  AppNotification _asRead(AppNotification n) => AppNotification(
        id: n.id,
        title: n.title,
        body: n.body,
        actionUrl: n.actionUrl,
        isRead: true,
        time: n.time,
      );
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsPage>(
        NotificationsController.new);

/// Badge jumlah belum dibaca — dipisah agar murah di-refresh tanpa
/// memuat seluruh daftar.
class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;

  /// Ambil ulang dari server (dipakai saat kembali ke halaman utama).
  Future<void> reload() async {
    try {
      final page =
          await ref.read(notifikasiRepositoryProvider).getNotifications();
      set(page.unreadCount);
    } on ApiException catch (_) {
      // Diam: badge tetap pada nilai terakhir saat gagal jaringan.
    }
  }
}

final unreadCountProvider =
    NotifierProvider<UnreadCountNotifier, int>(UnreadCountNotifier.new);
