import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
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
    final data = message.data;
    final route = data['route']?.toString();
    final id = data['id']?.toString();

    if (route != null && route.isNotEmpty) {
      // Navigate ke route spesifik dari FCM data (Fase 2 - precision deep-link).
      // If id is provided, it can be used to construct more specific routes
      if (id != null && id.isNotEmpty) {
        // Example: route="/armada/servis" + id="123" → "/armada/servis/123"
        final specificRoute = route.endsWith('/') ? '$route$id' : '$route/$id';
        router.go(specificRoute);
      } else {
        router.go(route);
      }
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
