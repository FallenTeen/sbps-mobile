/// Logika murni freshness tracking (Phase 15).
///
/// Semua perhitungan bersumber dari timestamp AKTUAL server (`last_seen`,
/// `aktif_sejak`). Tidak ada asumsi realtime: bila datanya lama, UI WAJIB
/// menyebut keterlambatannya (mis. "Lokasi terakhir 18 menit lalu") — bukan
/// berpura-pura live.
library;

import 'models.dart';

/// Ambang kapan lokasi dianggap "lama / stale".
const kTrackingStaleAfter = Duration(minutes: 5);

enum TrackingFreshnessState { fresh, stale, noData }

class TrackingFreshness {
  const TrackingFreshness._({required this.state, required this.age});

  final TrackingFreshnessState state;

  /// Umur data GPS relatif terhadap acuan waktu.
  final Duration age;

  bool get hasData => state != TrackingFreshnessState.noData;
  bool get isStale => state == TrackingFreshnessState.stale;
}

/// Hitung kesegaran lokasi dari [lastSeen] vs [now]. Murni selisih
/// timestamp aktual — tidak memakai clock GPS/lokal perangkat secara
/// terselubung.
TrackingFreshness trackingFreshness(
  DateTime? lastSeen, {
  DateTime? now,
  Duration staleAfter = kTrackingStaleAfter,
}) {
  final reference = now ?? DateTime.now();
  if (lastSeen == null) {
    return const TrackingFreshness._(
      state: TrackingFreshnessState.noData,
      age: Duration.zero,
    );
  }
  final age = reference.difference(lastSeen);
  return TrackingFreshness._(
    state: age > staleAfter
        ? TrackingFreshnessState.stale
        : TrackingFreshnessState.fresh,
    age: age,
  );
}

/// Teks keterangan posisi yang jujur terhadap umur data:
/// - stale  → "Lokasi terakhir 18 menit lalu."
/// - fresh  → "Terakhir update 2 menit lalu"
/// - noData → "Belum ada GPS tercatat hari ini."
String lokasiTerakhirText(
  DateTime? lastSeen, {
  DateTime? now,
  Duration staleAfter = kTrackingStaleAfter,
}) {
  final f = trackingFreshness(lastSeen, now: now, staleAfter: staleAfter);
  if (!f.hasData) return 'Belum ada GPS tercatat hari ini.';
  if (f.isStale) {
    final menit = f.age.inMinutes < 1 ? 1 : f.age.inMinutes;
    return 'Lokasi terakhir $menit menit lalu.';
  }
  return 'Terakhir update ${_fmtRelatifMenit(lastSeen!, now ?? DateTime.now())}';
}

/// "Aktif sejak 08:03" — murni dari waktu check-in server.
String aktifSejakText(DateTime? aktifSejak) {
  if (aktifSejak == null) return 'Aktif sejak belum diketahui';
  final l = aktifSejak.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return 'Aktif sejak $hh:$mm';
}

/// Munculkan "X menit lalu" (antar-notif kecil). Baru saja bila < 1 menit.
String _fmtRelatifMenit(DateTime dt, DateTime now) {
  final diff = now.difference(dt);
  if (diff.inSeconds < 60) return 'baru saja';
  return '${diff.inMinutes} menit lalu';
}

/// Urutkan user: yang paling baru update GPS di atas; tanpa GPS di akhir.
/// Urutan ini konsisten dengan fakta server (timestamp aktual).
List<ActiveUser> sortActiveUsers(List<ActiveUser> users) {
  final copy = [...users];
  copy.sort((a, b) {
    final aSeen = a.lastSeen;
    final bSeen = b.lastSeen;
    if (aSeen == null && bSeen == null) return 0;
    if (aSeen == null) return 1;
    if (bSeen == null) return -1;
    return bSeen.compareTo(aSeen);
  });
  return copy;
}

/// Label status chip: Aktif / Stale / Belum ada GPS.
String statusLabel(TrackingFreshness f) => switch (f.state) {
  TrackingFreshnessState.fresh => 'Aktif',
  TrackingFreshnessState.stale => 'Stale',
  TrackingFreshnessState.noData => 'Belum ada GPS',
};