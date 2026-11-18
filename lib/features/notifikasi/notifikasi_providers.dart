import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_preferences.dart';
import '../auth/auth_providers.dart';
import 'models/notification.dart';
import 'notifikasi_repository.dart';

final notifikasiRepositoryProvider = Provider<NotifikasiRepository>(
  (ref) => NotifikasiRepository(api: ref.watch(apiClientProvider)),
);

/// Daftar notifikasi (maks 50 terbaru) + unread count.
///
/// Arsip bersifat lokal (server belum punya endpoint archive): id yang
/// diarsip disimpan di Hive dan difilter dari daftar utama.
class NotificationsController extends AsyncNotifier<NotificationsPage> {
  static const _kArchivedKey = 'archived_notification_ids';

  Set<String> _archivedIds = {};

  /// Unread menurut server (termasuk yang diarsip lokal).
  int _rawUnread = 0;

  @override
  Future<NotificationsPage> build() async {
    final page = await ref
        .read(notifikasiRepositoryProvider)
        .getNotifications();
    _archivedIds = await _loadArchivedIds();
    _rawUnread = page.unreadCount;
    return _rebuild(page.items);
  }

  /// Arsip lokal tidak boleh menggagalkan daftar utama (mis. Hive belum
  /// siap): gagal baca dianggap tidak ada arsip.
  Future<Set<String>> _loadArchivedIds() async {
    try {
      final raw = await AppPreferences.getString(_kArchivedKey);
      return (raw ?? '').split(',').where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Susun state: terapkan flag arsip lokal & hitung unread efektif
  /// (unread server dikurangi notifikasi diarsip yang belum dibaca).
  NotificationsPage _rebuild(List<AppNotification> items) {
    final archivedUnread = items
        .where((n) => _archivedIds.contains(n.id) && !n.isRead)
        .length;
    final flagged = items
        .map((n) => n.copyWith(isArchived: _archivedIds.contains(n.id)))
        .toList();
    final unread = math.max(0, _rawUnread - archivedUnread);
    ref.read(unreadCountProvider.notifier).set(unread);
    return NotificationsPage(items: flagged, unreadCount: unread);
  }

  Future<void> refresh() async {
    try {
      final page = await ref
          .read(notifikasiRepositoryProvider)
          .getNotifications();
      _rawUnread = page.unreadCount;
      state = AsyncData(_rebuild(page.items));
    } on ApiException catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> _persistArchived() async {
    try {
      await AppPreferences.setString(_kArchivedKey, _archivedIds.join(','));
    } catch (_) {
      // Arsip tetap berlaku untuk sesi ini walau gagal disimpan.
    }
  }

  /// Arsipkan notifikasi secara lokal: hilang dari daftar utama, tetap
  /// tersimpan di arsip perangkat (menu "Arsip").
  Future<void> archive(AppNotification notification) async {
    _archivedIds.add(notification.id);
    await _persistArchived();
    final current = state.value;
    if (current != null) state = AsyncData(_rebuild(current.items));
  }

  /// Kembalikan satu notifikasi dari arsip ke daftar utama.
  Future<void> restore(String id) async {
    if (!_archivedIds.remove(id)) return;
    await _persistArchived();
    final current = state.value;
    if (current != null) state = AsyncData(_rebuild(current.items));
  }

  /// Tampilkan kembali semua notifikasi yang diarsip (kosongkan arsip
  /// lokal; server tetap sumber kebenaran).
  Future<void> restoreAll() async {
    if (_archivedIds.isEmpty) return;
    _archivedIds.clear();
    await _persistArchived();
    final current = state.value;
    if (current != null) state = AsyncData(_rebuild(current.items));
  }

  /// Notifikasi yang sedang diarsip lokal.
  List<AppNotification> get archivedItems =>
      (state.value?.items ?? const <AppNotification>[])
          .where((n) => n.isArchived)
          .toList();

  /// Tandai satu notifikasi dibaca: panggil server, lalu perbarui list &
  /// badge secara optimis. Mengembalikan pesan error bila gagal.
  Future<String?> markRead(AppNotification notification) async {
    if (notification.isRead) return null;
    try {
      await ref.read(notifikasiRepositoryProvider).markRead(notification.id);
      if (_rawUnread > 0) _rawUnread--;
      final current = state.value;
      if (current != null) {
        state = AsyncData(
          _rebuild(
            current.items
                .map(
                  (n) => n.id == notification.id ? n.copyWith(isRead: true) : n,
                )
                .toList(),
          ),
        );
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  /// Tandai semua belum dibaca sebagai sudah dibaca: update lokal optimis,
  /// lalu sinkron berurutan ke server. Gagal jaringan tidak menggagalkan
  /// tampilan - state lokal tetap "dibaca", server tersinkron saat refresh.
  Future<void> markAllRead() async {
    final current = state.value;
    if (current == null) return;
    final unread = current.items.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    _rawUnread = 0;
    state = AsyncData(
      _rebuild([for (final n in current.items) n.copyWith(isRead: true)]),
    );

    for (final n in unread) {
      try {
        await ref.read(notifikasiRepositoryProvider).markRead(n.id);
      } on ApiException {
        // State lokal tetap konsisten; sinkronisasi ulang saat refresh.
      }
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsController, NotificationsPage>(
      NotificationsController.new,
    );

/// Badge jumlah belum dibaca - dipisah agar murah di-refresh tanpa
/// memuat seluruh daftar.
class UnreadCountNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;

  /// Ambil ulang dari server (dipakai saat kembali ke halaman utama).
  Future<void> reload() async {
    try {
      final page = await ref
          .read(notifikasiRepositoryProvider)
          .getNotifications();
      set(page.unreadCount);
    } on ApiException catch (_) {
      // Diam: badge tetap pada nilai terakhir saat gagal jaringan.
    }
  }
}

final unreadCountProvider = NotifierProvider<UnreadCountNotifier, int>(
  UnreadCountNotifier.new,
);
