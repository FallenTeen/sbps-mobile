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

  // -------------------------------------------------------------------
  // ActiveUser.fromJson — koordinat GPS terakhir + url dari server
  // -------------------------------------------------------------------
  group('ActiveUser.fromJson last_lat/last_lng/google_maps_url', () {
    test('parse koordinat & url dari server', () {
      final u = ActiveUser.fromJson({
        'user_id': '7',
        'nama': 'Budi',
        'last_lat': -7.101,
        'last_lng': 110.202,
        'google_maps_url':
            'https://www.google.com/maps/search/?api=1&query=-7.101%2C110.202',
      });
      expect(u.lastLat, -7.101);
      expect(u.lastLng, 110.202);
      expect(u.googleMapsUrlFromServer,
          'https://www.google.com/maps/search/?api=1&query=-7.101%2C110.202');
    });

    test('tanpa koordinat → semua null', () {
      final u = ActiveUser.fromJson({'user_id': '1', 'nama': 'A'});
      expect(u.lastLat, isNull);
      expect(u.lastLng, isNull);
      expect(u.googleMapsUrlFromServer, isNull);
    });
  });

  // -------------------------------------------------------------------
  // TrailData.fromRaw — last-point overview dari server
  // -------------------------------------------------------------------
  group('TrailData.fromRaw last_* overview', () {
    test('parse last_lat/last_lng/google_maps_url', () {
      final data = TrailData.fromRaw({
        'user_id': '7',
        'last_lat': -7.4685527,
        'last_lng': 109.217636,
        'google_maps_url':
            'https://www.google.com/maps/search/?api=1&query=-7.4685527%2C109.217636',
        'items': [
          {'lat': -7.4, 'lng': 109.2, 'timestamp': '2026-09-17T10:15:00'},
        ],
      });
      expect(data.lastLat, -7.4685527);
      expect(data.lastLng, 109.217636);
      expect(data.googleMapsUrlFromServer,
          'https://www.google.com/maps/search/?api=1&query=-7.4685527%2C109.217636');
      expect(data.items, hasLength(1));
    });

    test('tanpa last_* → null', () {
      final data = TrailData.fromRaw({'user_id': '7', 'items': []});
      expect(data.lastLat, isNull);
      expect(data.lastLng, isNull);
      expect(data.googleMapsUrlFromServer, isNull);
    });
  });

  // -------------------------------------------------------------------
  // Google Maps URL — format universal sama dengan server (GeoUrl.php)
  // -------------------------------------------------------------------
  group('googleMapsUrl / resolveLocationUrl', () {
    test('format universal: query=lat%2Clng', () {
      expect(
        googleMapsUrl(-7.101, 110.202),
        'https://www.google.com/maps/search/?api=1&query=-7.101%2C110.202',
      );
      expect(
        googleMapsUrl(-7.4685527, 109.217636),
        'https://www.google.com/maps/search/?api=1&query=-7.4685527%2C109.217636',
      );
    });

    test('resolveLocationUrl utamakan url dari server', () {
      final url = resolveLocationUrl(
        fromServer: 'https://www.google.com/maps/search/?api=1&query=-7.1%2C110.2',
        lat: -7.4,
        lng: 109.2,
      );
      expect(url, 'https://www.google.com/maps/search/?api=1&query=-7.1%2C110.2');
    });

    test('resolveLocationUrl fallback koordinat lokal bila server kosong', () {
      final url = resolveLocationUrl(
        fromServer: null,
        lat: -7.101,
        lng: 110.202,
      );
      expect(url, 'https://www.google.com/maps/search/?api=1&query=-7.101%2C110.202');
    });

    test('resolveLocationUrl null bila tidak ada koordinat sama sekali', () {
      expect(resolveLocationUrl(), isNull);
      expect(
        resolveLocationUrl(fromServer: '', lat: null, lng: null),
        isNull,
      );
    });
  });
}