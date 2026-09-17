import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/tracking/models.dart';
import 'package:sbps_mobile/features/tracking/tracking_rules.dart';

void main() {
  // -------------------------------------------------------------------
  // ActiveUser.fromJson — menoleransi last_seen / aktif_sejak null
  // -------------------------------------------------------------------
  group('ActiveUser.fromJson', () {
    test('parse titik, aktif_sejak, last_seen, point_count', () {
      final u = ActiveUser.fromJson({
        'user_id': 7,
        'nama': 'Budi',
        'karyawan_id': 'k-2',
        'titik': 'Titik A',
        'aktif_sejak': '2026-09-17T07:20:00',
        'last_seen': '2026-09-17T10:15:00',
        'point_count': 42,
      });
      expect(u.userId, '7');
      expect(u.nama, 'Budi');
      expect(u.karyawanId, 'k-2');
      expect(u.titik, 'Titik A');
      expect(u.aktifSejak, DateTime(2026, 9, 17, 7, 20));
      expect(u.lastSeen, DateTime(2026, 9, 17, 10, 15));
      expect(u.pointCount, 42);
    });

    test('last_seen null / kosong → lastSeen null', () {
      expect(
        ActiveUser.fromJson({'user_id': '1', 'nama': 'A', 'last_seen': null})
            .lastSeen,
        isNull,
      );
      expect(
        ActiveUser.fromJson({'user_id': '1', 'nama': 'A', 'last_seen': ''})
            .lastSeen,
        isNull,
      );
    });

    test('titik & aktif_sejak boleh tidak ada', () {
      final u = ActiveUser.fromJson({'user_id': '1', 'nama': 'A'});
      expect(u.titik, isNull);
      expect(u.aktifSejak, isNull);
      expect(u.pointCount, 0);
    });
  });

  // -------------------------------------------------------------------
  // trackingFreshness — selisih timestamp server, bukan realtime buatan
  // -------------------------------------------------------------------
  group('trackingFreshness', () {
    final now = DateTime(2026, 9, 17, 12, 0, 0);

    test('last_seen baru (< staleAfter) → fresh', () {
      final f = trackingFreshness(
        DateTime(2026, 9, 17, 11, 59),
        now: now,
      );
      expect(f.state, TrackingFreshnessState.fresh);
      expect(f.age, const Duration(minutes: 1));
      expect(f.hasData, isTrue);
      expect(f.isStale, isFalse);
    });

    test('tepat di ambang kStalingStaleAfter (5 menit) → fresh', () {
      final f = trackingFreshness(
        DateTime(2026, 9, 17, 11, 55),
        now: now,
      );
      expect(f.state, TrackingFreshnessState.fresh);
    });

    test('lewat ambang → stale', () {
      final f = trackingFreshness(
        DateTime(2026, 9, 17, 11, 54),
        now: now,
      );
      expect(f.state, TrackingFreshnessState.stale);
      expect(f.isStale, isTrue);
    });

    test('last_seen null → noData, hasData false', () {
      final f = trackingFreshness(null, now: now);
      expect(f.state, TrackingFreshnessState.noData);
      expect(f.hasData, isFalse);
    });
  });

  // -------------------------------------------------------------------
  // lokasiTerakhirText — jujur terhadap umur data server
  // -------------------------------------------------------------------
  group('lokasiTerakhirText', () {
    final now = DateTime(2026, 9, 17, 12, 0, 0);

    test('stale → menebus dengan "Lokasi terakhir N menit lalu."', () {
      final text = lokasiTerakhirText(
        DateTime(2026, 9, 17, 11, 42),
        now: now,
      );
      expect(text, 'Lokasi terakhir 18 menit lalu.');
    });

    test('stale persis 5 menit lebih → "Lokasi terakhir 5 menit lalu."', () {
      final text = lokasiTerakhirText(
        DateTime(2026, 9, 17, 11, 54, 50),
        now: now,
      );
      expect(text, 'Lokasi terakhir 5 menit lalu.');
    });

    test('fresh 1 menit → "Terakhir update 1 menit lalu"', () {
      final text = lokasiTerakhirText(
        DateTime(2026, 9, 17, 11, 59),
        now: now,
      );
      expect(text, 'Terakhir update 1 menit lalu');
    });

    test('fresh → "Terakhir update X menit lalu"', () {
      final text = lokasiTerakhirText(
        DateTime(2026, 9, 17, 11, 58),
        now: now,
      );
      expect(text, 'Terakhir update 2 menit lalu');
    });

    test('fresh < 1 menit → "Terakhir update baru saja"', () {
      final text = lokasiTerakhirText(
        DateTime(2026, 9, 17, 11, 59, 40),
        now: now,
      );
      expect(text, 'Terakhir update baru saja');
    });

    test('noData → "Belum ada GPS tercatat hari ini."', () {
      expect(lokasiTerakhirText(null, now: now),
          'Belum ada GPS tercatat hari ini.');
    });
  });

  // -------------------------------------------------------------------
  // aktifSejakText — dari waktu check-in server
  // -------------------------------------------------------------------
  group('aktifSejakText', () {
    test('format HH:mm dari waktu check-in', () {
      expect(aktifSejakText(DateTime(2026, 9, 17, 8, 3)), 'Aktif sejak 08:03');
      expect(aktifSejakText(DateTime(2026, 9, 17, 18, 45)),
          'Aktif sejak 18:45');
    });

    test('null → ucapkan belum diketahui', () {
      expect(aktifSejakText(null), 'Aktif sejak belum diketahui');
    });
  });

  // -------------------------------------------------------------------
  // sortActiveUsers — GPS terbaru di atas, tanpa GPS di paling bawah
  // -------------------------------------------------------------------
  group('sortActiveUsers', () {
    ActiveUser user(String id, DateTime? seen) => ActiveUser(
      userId: id,
      nama: id,
      lastSeen: seen,
    );

    test('urutkan menurun berdasarkan last_seen', () {
      final now = DateTime(2026, 9, 17, 10, 0);
      final sorted = sortActiveUsers([
        user('a', now.subtract(const Duration(minutes: 20))),
        user('b', now.subtract(const Duration(minutes: 2))),
        user('c', now.subtract(const Duration(minutes: 10))),
      ]);
      expect(sorted.map((u) => u.userId), ['b', 'c', 'a']);
    });

    test('tanpa last_seen selalu di akhir', () {
      final sorted = sortActiveUsers([
        user('a', null),
        user('b', DateTime(2026, 9, 17, 9, 0)),
        user('c', null),
      ]);
      expect(sorted.map((u) => u.userId), ['b', 'a', 'c']);
    });

    test('list kosong aman', () {
      expect(sortActiveUsers([]), isEmpty);
    });
  });

  // -------------------------------------------------------------------
  // statusLabel
  // -------------------------------------------------------------------
  group('statusLabel', () {
    test('label sesuai state freshness', () {
      expect(statusLabel(trackingFreshness(DateTime.now())), 'Aktif');
      expect(
        statusLabel(
          trackingFreshness(DateTime.now().subtract(const Duration(minutes: 10))),
        ),
        'Stale',
      );
      expect(
        statusLabel(trackingFreshness(null, now: DateTime.now())),
        'Belum ada GPS',
      );
    });
  });
}