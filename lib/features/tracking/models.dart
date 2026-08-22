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

/// Item GET /tracking/active-users — user dengan GPS dalam 1 jam terakhir.
class ActiveUser {
  const ActiveUser({
    required this.userId,
    required this.nama,
    this.karyawanId,
    this.lastSeen,
    this.pointCount = 0,
  });

  final String userId;
  final String nama;
  final String? karyawanId;
  final DateTime? lastSeen;
  final int pointCount;

  factory ActiveUser.fromJson(Map<String, dynamic> json) {
    final lastSeenRaw = json['last_seen']?.toString();
    return ActiveUser(
      userId: json['user_id']?.toString() ?? '',
      nama: json['nama']?.toString() ?? '',
      karyawanId: json['karyawan_id']?.toString(),
      lastSeen:
          lastSeenRaw == null || lastSeenRaw.isEmpty ? null : DateTime.tryParse(lastSeenRaw),
      pointCount: (json['point_count'] as num?)?.toInt() ?? 0,
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
  });

  final String userId;
  final String? nama;
  final String? tanggal;
  final List<TrackPoint> items;

  static TrailData fromRaw(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    final list = map['items'];
    return TrailData(
      userId: map['user_id']?.toString() ?? '',
      nama: map['nama']?.toString(),
      tanggal: map['tanggal']?.toString(),
      items: [
        if (list is List)
          for (final e in list)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}
