import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';
import 'package:sbps_mobile/shared/utils/feedback_copy.dart';

void main() {
  group('Feedback copy standar sinkronisasi (PHASE 04)', () {
    test('copy queued tidak mengklaim berhasil tersimpan ke server', () {
      expect(kCopyQueued, 'Tersimpan di perangkat. Menunggu sinkronisasi.');
      expect(kCopyQueued.contains('berhasil'), isFalse);
      expect(kCopyQueued.contains('berhasil disimpan'), isFalse);
    });

    test('copy synced mengklaim server sudah menerima', () {
      expect(kCopySynced, 'Berhasil disinkronkan.');
    });

    test('copy failed mengarahkan retry', () {
      expect(kCopyFailed, 'Data belum tersinkron. Coba lagi.');
    });
  });

  group('friendlyErrorMessage', () {
    test('ApiException meneruskan pesan server', () {
      expect(
        friendlyErrorMessage(ApiException('Data sudah pernah dimasukkan')),
        'Data sudah pernah dimasukkan',
      );
    });

    test('error teknis tidak bocor ke user (fallback diberi pesan umum)', () {
      final e = StateError('SocketException: Failed host lookup: api.local');
      expect(friendlyErrorMessage(e), kCopyConnError);
      expect(friendlyErrorMessage(e).contains('SocketException'), isFalse);
    });

    test('fallback kustom dipakai bila error bukan ApiException', () {
      expect(
        friendlyErrorMessage(Exception('boom'), fallback: 'Gagal memuat.'),
        'Gagal memuat.',
      );
    });
  });
}