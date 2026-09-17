import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_router.dart';
import '../../core/push_token_service.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/notifikasi/models/notification.dart';
import '../../features/notifikasi/notifikasi_providers.dart';
import 'notification_routes.dart';

/// Handler for notification taps — navigate ke layar terkait.
///
/// Mendukung 2 skenario:
/// 1. App sudah terbuka (background) → onMessageOpenedApp
/// 2. App dalam killed state → getInitialMessage
///
/// Deep link diresolusi lewat `notification_routes.dart` dengan payload FCM:
/// - `action_url` / `route` + `route_id`: path go_router tujuan
/// - `notification_id`: id notifikasi untuk markRead best-effort (hanya
///   dipakai bila ada; `id` di payload lama bisa berarti id record route)
class NotificationHandler {
  NotificationHandler._();

  static final instance = NotificationHandler._();

  StreamSubscription<RemoteMessage>? _sub;
  bool _initialized = false;
  WidgetRef? _ref;

  void initialize(WidgetRef ref) {
    if (_initialized) return;
    _initialized = true;
    _ref = ref;

    final router = ref.read(appRouterProvider);

    // Firebase Web bersifat opsional untuk local development. Android/iOS
    // tetap memakai konfigurasi native saat Firebase sudah diinisialisasi.
    if (Firebase.apps.isEmpty) return;

    try {
      // 1. App dibuka dari killed state via notifikasi.
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) _handleTap(router, message);
      });

      // 2. App di-background, user tap notifikasi.
      _sub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleTap(router, message);
      });
    } catch (error) {
      debugPrint('[FCM] Notification handler disabled: $error');
    }
  }

  void _handleTap(GoRouter router, RemoteMessage message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    try {
      final data = Map<String, dynamic>.from(message.data);
      final resolved = resolveNotificationDestination(
        notification: AppNotification(
          id: data['notification_id']?.toString() ?? '',
          isRead: false,
          actionUrl: data['action_url']?.toString(),
          route: data['route']?.toString(),
          routeId:
              data['route_id']?.toString() ?? data['id']?.toString(),
        ),
        role: _ref?.read(activeRoleProvider),
      );

      switch (resolved.status) {
        case NotificationTargetStatus.open:
          // push (bukan go) supaya back stack tetap utuh — user bisa kembali
          // ke layar sebelumnya setelah melihat tujuan notifikasi.
          router.push(resolved.route!);
          _markReadBestEffort(data);
        case NotificationTargetStatus.openExternal:
        case NotificationTargetStatus.unavailable:
          router.push('/notifikasi');
        case NotificationTargetStatus.deniedRole:
          router.push('/notifikasi');
          final messageText = notificationDestinationMessage(resolved);
          if (messageText != null && messenger != null) {
            messenger.showSnackBar(SnackBar(content: Text(messageText)));
          }
      }
    } catch (error) {
      debugPrint('[FCM] Navigation failed: $error');
      try {
        router.push('/notifikasi');
      } catch (_) {
        // Router belum siap — biarkan user tetap di layar sekarang.
      }
    }
  }

  /// Tandai dibaca best-effort. HANYA saat payload membawa `notification_id`
  /// eksplisit — payload lama memakai `id` sebagai id record route, sehingga
  /// menandai sembarangan bisa menandai record yang salah.
  Future<void> _markReadBestEffort(Map<String, dynamic> data) async {
    final notificationId = data['notification_id']?.toString();
    if (notificationId == null || notificationId.isEmpty) return;
    final ref = _ref;
    if (ref == null) return;
    try {
      await ref
          .read(notifikasiRepositoryProvider)
          .markRead(notificationId);
      ref.read(unreadCountProvider.notifier).reload();
    } catch (error) {
      // Best-effort saja — jaringan/read gagal tidak boleh mengganggu navigasi.
      debugPrint('[FCM] markRead best-effort failed: $error');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}