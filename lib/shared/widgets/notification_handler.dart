import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_router.dart';

/// Handler untuk notification taps — navigate ke layar terkait.
///
/// Mendukung 2 skenario:
/// 1. App sudah terbuka (background) → onMessageOpenedApp
/// 2. App dalam killed state → getInitialMessage
///
/// Deep link berdasarkan `data` payload dari FCM:
/// - `route`: path go_router (mis. `/armada/servis/123`)
/// - `title`, `body`: info notifikasi
class NotificationHandler {
  NotificationHandler._();

  static final instance = NotificationHandler._();

  StreamSubscription<RemoteMessage>? _sub;
  bool _initialized = false;

  void initialize(WidgetRef ref) {
    if (_initialized) return;
    _initialized = true;

    final router = ref.read(appRouterProvider);

    // 1. App dibuka dari killed state via notifikasi.
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleTap(router, message);
    });

    // 2. App di-background, user tap notifikasi.
    _sub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(router, message);
    });
  }

  void _handleTap(GoRouter router, RemoteMessage message) {
    final data = message.data;
    final route = data['route']?.toString();

    if (route != null && route.isNotEmpty) {
      // Navigate ke route spesifik dari FCM data.
      router.go(route);
    } else if (data['screen'] != null) {
      // Fallback: map screen name ke route.
      final screen = data['screen'].toString();
      final routeMap = <String, String>{
        'armada': '/armada',
        'servis': '/armada/servis',
        'checklist': '/armada/checklist',
        'dashboard': '/dashboard',
        'notifikasi': '/home',
      };
      final target = routeMap[screen];
      if (target != null) router.go(target);
    } else {
      // Default: buka notifikasi list.
      router.go('/home');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
