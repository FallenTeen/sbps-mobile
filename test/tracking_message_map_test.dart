import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/tracking/tracking_providers.dart';

void main() {
  group('mapTrackingMessage', () {
    test('null/kosong tetap null', () {
      expect(mapTrackingMessage(null), isNull);
      expect(mapTrackingMessage('   '), isNull);
    });

    test('401 / unauthenticated jadi pesan sesi berakhir', () {
      expect(
        mapTrackingMessage('Unauthenticated.'),
        'Sesi berakhir, silakan login ulang.',
      );
      expect(
        mapTrackingMessage('HTTP 401 Unauthorized'),
        'Sesi berakhir, silakan login ulang.',
      );
    });

    test('server 500 jadi pesan server bermasalah', () {
      expect(
        mapTrackingMessage('Internal Server Error'),
        'Server sedang bermasalah, lokasi tetap disimpan di HP.',
      );
    });

    test('jaringan/timeout jadi pesan koneksi internet', () {
      expect(
        mapTrackingMessage('DioException [connection timeout]'),
        'Koneksi internet bermasalah, lokasi tetap disimpan di HP.',
      );
      expect(
        mapTrackingMessage('Gagal mengirim lokasi.'),
        'Koneksi internet bermasalah, lokasi tetap disimpan di HP.',
      );
    });

    test('pesan izin yang sudah jelas diteruskan apa adanya', () {
      const izin = 'Izin lokasi belakang belum aktif - lokasi terkirim '
          'hanya saat aplikasi dibuka.';
      expect(mapTrackingMessage(izin), izin);
    });
  });

  group('shouldPromptAlwaysPermission', () {
    final now = DateTime(2026, 11, 13);

    test('tidak pernah prompt dua kali per sesi', () {
      expect(
        shouldPromptAlwaysPermission(
          promptedThisSession: true,
          lastPromptAt: null,
          now: now,
        ),
        isFalse,
      );
    });

    test('belum pernah prompt, boleh prompt', () {
      expect(
        shouldPromptAlwaysPermission(
          promptedThisSession: false,
          lastPromptAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('kurang dari 7 hari, tidak prompt ulang', () {
      expect(
        shouldPromptAlwaysPermission(
          promptedThisSession: false,
          lastPromptAt: now.subtract(const Duration(days: 6)),
          now: now,
        ),
        isFalse,
      );
    });

    test('7 hari atau lebih, boleh prompt ulang', () {
      expect(
        shouldPromptAlwaysPermission(
          promptedThisSession: false,
          lastPromptAt: now.subtract(const Duration(days: 7)),
          now: now,
        ),
        isTrue,
      );
    });
  });
}
