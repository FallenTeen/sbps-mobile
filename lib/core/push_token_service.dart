import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Sumber device token push (FCM) untuk field `device_token` pada
/// login/register.
///
/// Membutuhkan file konfigurasi Firebase per flavor:
/// - App 1 (presensi): `android/app/src/presensi/google-services.json`
///                    & `ios/Runner/GoogleService-Info-presensi.plist`
/// - App 2 (proyek):   `android/app/src/proyek/google-services.json`
///                    & `ios/Runner/GoogleService-Info-proyek.plist`
///
/// Jika Firebase belum dikonfigurasi, token dikembalikan null — backend
/// menerima login tanpa `device_token` karena field tersebut opsional.
class PushTokenService {
  PushTokenService({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;
  String? _cachedToken;

  FirebaseMessaging? get _fm => _messaging;

  /// Token FCM aktif, atau null bila Firebase belum dikonfigurasi.
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    if (_fm == null) return null;

    try {
      // Minta permission (Android 13+ / iOS wajib).
      final settings = await _fm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[PushToken] Permission denied by user.');
        return null;
      }

      final token = await _fm!.getToken();
      _cachedToken = token;

      // Refresh token listener — simpan token baru saat FCM rotate.
      _fm!.onTokenRefresh.listen((newToken) {
        _cachedToken = newToken;
        debugPrint('[PushToken] Token refreshed: ${newToken.substring(0, 20)}...');
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
}

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Handler untuk pesan yang diterima saat app di foreground.
/// Dipanggil dari main.dart setelah Firebase.initializeApp().
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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
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
