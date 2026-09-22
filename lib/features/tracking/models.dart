import '../../core/json_num.dart';

/// Titik lokasi GPS hasil perekaman perangkat.
class TrackPoint {
  const TrackPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final DateTime timestamp;

  /// ID stabil = ISO timestamp — dipakai untuk menghapus titik tertentu
  /// dari buffer setelah batch-nya terkirim.
  String get id => timestamp.toIso8601String();

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'timestamp': timestamp.toIso8601String(),
  };

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Format body `locations[]` sesuai docs/api-mobile.md §9.1.
  Map<String, dynamic> toApiJson() => {
    'lat': lat,
    'lng': lng,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Item GET /tracking/active-users — karyawan yang masih ber-presensi aktif
/// hari ini beserta status GPS aktual dari server:
/// [titik], [aktifSejak] (waktu check-in), [lastSeen] (GPS terakhir hari ini,
/// null bila belum ada), [pointCount] (titik GPS hari ini), plus koordinat &
/// URL Google Maps dari lokasi GPS terakhir ([lastLat]/[lastLng]/
/// [googleMapsUrlFromServer], semuanya null bila server belum punya GPS).
class ActiveUser {
  const ActiveUser({
    required this.userId,
    required this.nama,
    this.karyawanId,
    this.titik,
    this.aktifSejak,
    this.lastSeen,
    this.pointCount = 0,
    this.lastLat,
    this.lastLng,
    this.googleMapsUrlFromServer,
  });

  final String userId;
  final String nama;
  final String? karyawanId;

  /// Titik kerja dari presensi aktif (nama), bila tersedia dari server.
  final String? titik;

  /// Waktu check-in yang masih aktif — dasar teks "aktif sejak".
  final DateTime? aktifSejak;

  /// Timestamp lokasi GPS TERAKHIR hari ini. Null = belum ada GPS tercatat.
  final DateTime? lastSeen;
  final int pointCount;

  /// Koordinat GPS TERAKHIR hari ini dari server. Null = belum ada GPS
  /// tercatat (di luar lingkup radius namun server jujur menyatakannya).
  final double? lastLat;
  final double? lastLng;

  /// URL universal Google Maps untuk aksi "Buka di Google Maps"/"Bagikan
  /// Lokasi" — selalu pakai yang dikirim server (sumber kebenaran tunggal:
  /// sama formatnya di mobile & web), fallback dihitung lokal bila null.
  final String? googleMapsUrlFromServer;

  factory ActiveUser.fromJson(Map<String, dynamic> json) {
    final lastSeenRaw = json['last_seen']?.toString();
    final aktifSejakRaw = json['aktif_sejak']?.toString();
    return ActiveUser(
      userId: json['user_id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      karyawanId: json['karyawan_id']?.toString(),
      titik: json['titik']?.toString(),
      aktifSejak: aktifSejakRaw == null || aktifSejakRaw.isEmpty
          ? null
          : DateTime.tryParse(aktifSejakRaw),
      lastSeen: lastSeenRaw == null || lastSeenRaw.isEmpty
          ? null
          : DateTime.tryParse(lastSeenRaw),
      pointCount: parseInt(json['point_count']) ?? 0,
      lastLat: parseNum(json['last_lat']),
      lastLng: parseNum(json['last_lng']),
      googleMapsUrlFromServer: json['google_maps_url']?.toString(),
    );
  }
}

/// Data GET /tracking/hari-ini/{userId} — jejak lokasi satu user hari ini.
class TrailData {
  const TrailData({
    required this.userId,
    this.nama,
    this.tanggal,
    this.items = const [],
    this.lastLat,
    this.lastLng,
    this.googleMapsUrlFromServer,
  });

  final String userId;
  final String? nama;
  final String? tanggal;
  final List<TrackPoint> items;

  /// Last-point overview dari server (lokasi GPS TERAKHIR + URL Google Maps).
  /// Null bila hari ini belum ada GPS tercatat.
  final double? lastLat;
  final double? lastLng;
  final String? googleMapsUrlFromServer;

  static TrailData fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return TrailData(
      userId: map['user_id']?.toString() ?? '',
      nama: map['nama']?.toString(),
      tanggal: map['tanggal']?.toString(),
      lastLat: parseNum(map['last_lat']),
      lastLng: parseNum(map['last_lng']),
      googleMapsUrlFromServer: map['google_maps_url']?.toString(),
      items: [
        if (list is List)
          for (final e in list)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}
