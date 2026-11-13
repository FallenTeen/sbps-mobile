import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'storage/token_storage.dart';

/// Sumber device token FCM untuk field `device_token` pada login/register.
/// Firebase belum dikonfigurasi -> token null (backend menerima karena opsional).
class PushTokenService {
  PushTokenService({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;
  String? _cachedToken;

  FirebaseMessaging? get _fm => _messaging;

  /// Token FCM aktif, atau null bila Firebase belum dikonfigurasi.
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    if (Firebase.apps.isEmpty) return null;

    try {
      // Jangan akses FirebaseMessaging.instance sebelum Firebase siap.
      final messaging = _fm ?? FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushToken] Permission denied by user.');
        return null;
      }

      final token = await messaging.getToken();
      _cachedToken = token;

      // Refresh token listener — simpan token baru saat FCM rotate.
      messaging.onTokenRefresh.listen((newToken) {
        _cachedToken = newToken;
        debugPrint(
          '[PushToken] Token refreshed: ${newToken.substring(0, 20)}...',
        );
        // Kirim token baru ke server agar push tidak jatuh ke token usang.
        unawaited(syncTokenToServer(newToken));
      });

      if (token != null) {
        debugPrint('[PushToken] Got token: ${token.substring(0, 20)}...');
      }

      return token;
    } catch (e) {
      // Firebase belum dikonfigurasi atau error lain — aman return null.
      debugPrint('[PushToken] Failed to get token: $e');
      return null;
    }
  }
  /// Kirim token FCM terbaru ke backend agar push tidak jatuh ke token usang.
  Future<void> syncTokenToServer(String token) async {
    try {
      final storage = TokenStorage();
      final authToken = await storage.readToken();
      if (authToken == null || authToken.isEmpty) return;
      final activeRole = await storage.readActiveRole();
      final dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.requiredApiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $authToken',
            if (activeRole != null && activeRole.isNotEmpty)
              'X-Active-Role': activeRole,
          },
        ),
      );
      await dio.post('/push-token', data: {'device_token': token});
      debugPrint('[PushToken] Token synced to server.');
    } catch (e) {
      debugPrint('[PushToken] Sync token to server failed: $e');
    }
  }
}

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Handler pesan FCM saat app di foreground (dipanggil dari main.dart).
Future<void> firebaseMessagingForegroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Foreground message: ${message.messageId}');
  final notification = message.notification;
  if (notification != null) {
    final title = notification.title ?? 'Notifikasi Baru';
    final body = notification.body ?? '';

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
