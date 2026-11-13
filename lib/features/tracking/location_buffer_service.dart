import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/location_service.dart';
import 'models.dart';

/// Buffer titik GPS untuk tracking.
///
/// Perekam titik: pindah >= 50 meter ATAU tiap ~60 detik; tracking hanya
/// berjalan saat presensi terbuka (gate di [TrackingScheduler]).
///
/// Persistensi Hive box `tracking_buffer`:
/// - `points`: JSON list titik belum terkirim;
/// - `pending_batch`: batch yang menunggu keberhasilan kirim (batch_id +
///   isi persis) agar retry tetap idempotent;
/// - titik/batch kemarin dibuang otomatis (server tidak memakainya).
class LocationBufferService {
  static const _boxName = 'tracking_buffer';
  static const _maxPoints = 5000;

  final LocationService _location;

  StreamSubscription<Position>? _positionSub;
  Timer? _fallbackTimer;
  DateTime? _lastStoredAt;
  bool _running = false;
  bool _fallbackBusy = false;

  List<TrackPoint> _points = [];

  LocationBufferService(this._location);

  bool get isRunning => _running;
  int get count => _points.length;

  Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  Future<void> load() async {
    final box = await _box();
    final raw = box.get('points');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _points = [
          for (final e in list)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
      } catch (_) {
        _points = [];
      }
    }
    await pruneStale();
  }

  /// Mulai perekaman. Return pesan kesalahan bila gagal (izin/GPS mati),
  /// null bila sukses berjalan.
  Future<String?> start() async {
    if (_running) return null;
    if (!await _location.isServiceEnabled()) return 'Layanan lokasi mati.';
    if (!await _location.ensurePermission()) {
      return 'Izin lokasi belum diberikan.';
    }

    await load();

    // Kombinasi distanceFilter + intervalDuration: Android memancarkan
    // posisi saat pindah >= 50m ATAU lewat interval; iOS hanya distance.
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen(_onPosition);

    // Fallback perangkat yang tidak memancarkan event tanpa gerakan:
    // stream berbasis jarak (>=50 m) TIDAK emit apa pun saat karyawan
    // diam, jadi ambil posisi SEGAR tiap 60 detik agar lokasi tetap
    // ter-update walau tidak berpindah (dan timestamp tidak dobel).
    _fallbackTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      if (_fallbackBusy) return;
      final stored = _lastStoredAt;
      if (stored != null &&
          DateTime.now().difference(stored) < const Duration(seconds: 55)) {
        return;
      }
      _fallbackBusy = true;
      try {
        final pos = await _location.getCurrentPosition();
        if (pos != null) _onPosition(pos);
      } finally {
        _fallbackBusy = false;
      }
    });

    _running = true;
    return null;
  }

  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _running = false;
  }

  void _onPosition(Position position) {
    if (!_running) return;
    _lastStoredAt = DateTime.now();
    _addPoint(
      TrackPoint(
        lat: position.latitude,
        lng: position.longitude,
        timestamp: position.timestamp.toLocal(),
      ),
    );
  }

  Future<void> _addPoint(TrackPoint point) async {
    _points.add(point);
    if (_points.length > _maxPoints) {
      _points.removeRange(0, _points.length - _maxPoints);
    }
    await _persist();
  }

  Future<void> _persist() async {
    final box = await _box();
    await box.put('points', jsonEncode([for (final p in _points) p.toJson()]));
  }

  /// Buang titik/batch dari hari sebelumnya. Dipanggil saat `load()` dan
  /// setiap flush agar app yang menyala melewati tengah malam tetap rollover.
  Future<void> pruneStale() async {
    final midnight = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final before = _points.length;
    _points.removeWhere((p) => p.timestamp.isBefore(midnight));
    var changed = _points.length != before;

    // Batch pending yang titiknya semua kemarin tidak akan pernah
    // diterima server (presensi lama sudah ditutup) - buang agar tidak
    // loop retry 422 di hari baru.
    final pending = await readPendingBatch();
    if (pending != null && pending.points.isNotEmpty) {
      final semuaKemarin = pending.points
          .every((p) => p.timestamp.isBefore(midnight));
      if (semuaKemarin) {
        await clearPendingBatch();
        changed = true;
      }
    }

    if (changed) await _persist();
  }

  /// Ambil salinan titik yang belum masuk batch pending.
  List<TrackPoint> snapshot() => List.unmodifiable(_points);

  /// Gabungkan titik yang ditulis oleh background service isolate
  /// (langsung ke Hive box) ke list in-memory — dedupe by `id`.
  Future<void> syncFromStore() async {
    final box = await _box();
    final raw = box.get('points');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      final known = _points.map((p) => p.id).toSet();
      for (final e in list) {
        final p = TrackPoint.fromJson(Map<String, dynamic>.from(e as Map));
        if (known.add(p.id)) _points.add(p);
      }
      if (_points.length > _maxPoints) {
        _points.removeRange(0, _points.length - _maxPoints);
      }
    } catch (_) {
      // Data korup di box — biarkan in-memory untuk dipersist ulang.
    }
  }

  /// Append SATU titik langsung ke Hive — untuk panggilan dari
  /// background service isolate yang punya instance/memory sendiri
  /// (tidak bisa memakai instance LocationBufferService utama).
  static Future<void> appendPointIsolate({
    required double lat,
    required double lng,
    required DateTime timestamp,
  }) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final raw = box.get('points');
    List<TrackPoint> points = const [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        points = [
          for (final e in list)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
      } catch (_) {
        points = const [];
      }
    }

    // Prune kemarin juga di dalam isolate (day rollover offline semalam).
    final midnight = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    points = points.where((p) => p.timestamp.isAfter(midnight)).toList();

    points.add(
      TrackPoint(lat: lat, lng: lng, timestamp: timestamp.toLocal()),
    );
    if (points.length > LocationBufferService._maxPoints) {
      points.removeRange(0, points.length - LocationBufferService._maxPoints);
    }

    await box.put(
      'points',
      jsonEncode(
        [for (final p in points) p.toJson()],
      ),
    );
  }

  /// Buang titik/batch dari hari sebelumnya - versi isolate (tanpa in-memory).
  static Future<void> pruneStaleIsolate() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final raw = box.get('points');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        final midnight = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        final kept = [
          for (final e in list)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        ].where((p) => !p.timestamp.isBefore(midnight)).toList();
        await box.put(
          'points',
          jsonEncode([for (final p in kept) p.toJson()]),
        );
      } catch (_) {
        // Data korup - biarkan.
      }
    }

    // Batch pending yang titiknya semua kemarin dibuang.
    final pendingRaw = box.get('pending_batch');
    if (pendingRaw != null && pendingRaw.isNotEmpty) {
      try {
        final map = Map<String, dynamic>.from(jsonDecode(pendingRaw) as Map);
        final locs = map['locations'] as List? ?? const [];
        final pts = [
          for (final e in locs)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        ];
        final midnight = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        if (pts.isNotEmpty && pts.every((p) => p.timestamp.isBefore(midnight))) {
          await box.delete('pending_batch');
        }
      } catch (_) {
        await box.delete('pending_batch');
      }
    }
  }

  /// Ambil semua titik belum terkirim langsung dari Hive - versi isolate.
  static Future<List<TrackPoint>> snapshotIsolate() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final raw = box.get('points');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Baca batch pending langsung dari Hive - versi isolate.
  static Future<({String batchId, List<TrackPoint> points})?>
  readPendingBatchIsolate() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final raw = box.get('pending_batch');
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final locs = map['locations'] as List? ?? const [];
      return (
        batchId: map['batch_id'] as String,
        points: [
          for (final e in locs)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
    } catch (_) {
      await box.delete('pending_batch');
      return null;
    }
  }

  /// Simpan batch pending langsung ke Hive - versi isolate.
  static Future<void> savePendingBatchIsolate(
    String batchId,
    List<TrackPoint> points,
  ) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    await box.put(
      'pending_batch',
      jsonEncode({
        'batch_id': batchId,
        'locations': [for (final p in points) p.toJson()],
      }),
    );
  }

  /// Hapus batch pending langsung dari Hive - versi isolate.
  static Future<void> clearPendingBatchIsolate() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    await box.delete('pending_batch');
  }

  /// Hapus titik terkirim dari buffer - versi isolate.
  static Future<void> removeByIdsIsolate(Set<String> ids) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final raw = box.get('points');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      final kept = [
        for (final e in list)
          TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
      ].where((p) => !ids.contains(p.id)).toList();
      await box.put(
        'points',
        jsonEncode([for (final p in kept) p.toJson()]),
      );
    } catch (_) {
      // Abaikan.
    }
  }

  static Future<bool> isAuthBlocked() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final raw = box.get('auth_blocked_until');
    if (raw == null || raw.isEmpty) return false;
    try {
      final until = DateTime.parse(raw);
      if (DateTime.now().isBefore(until)) return true;
      await box.delete('auth_blocked_until');
      return false;
    } catch (_) {
      await box.delete('auth_blocked_until');
      return false;
    }
  }

  static Future<void> setAuthBlocked(Duration duration) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    await box.put(
      'auth_blocked_until',
      DateTime.now().add(duration).toIso8601String(),
    );
  }

  static Future<void> clearAuthBlocked() async {
    try {
      final box = await Hive.openBox<String>(LocationBufferService._boxName);
      await box.delete('auth_blocked_until');
    } catch (_) {}
  }

  static Future<void> setTrackingDesired(bool value) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    await box.put('tracking_desired', value ? 'true' : 'false');
  }

  static Future<bool> isTrackingDesired() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    return box.get('tracking_desired') == 'true';
  }

  // Cache token/role di Hive agar background isolate bisa membaca tanpa
  // platform channel (flutter_secure_storage sering gagal di isolate).
  static Future<void> cacheAuthToken(String? token) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    if (token == null || token.isEmpty) {
      await box.delete('cached_auth_token');
    } else {
      await box.put('cached_auth_token', token);
    }
  }

  static Future<String?> getCachedAuthToken() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final v = box.get('cached_auth_token');
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> cacheActiveRole(String? role) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    if (role == null || role.isEmpty) {
      await box.delete('cached_active_role');
    } else {
      await box.put('cached_active_role', role);
    }
  }

  static Future<String?> getCachedActiveRole() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final v = box.get('cached_active_role');
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static Future<void> setPresensiOpen(bool value) async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    await box.put('presensi_open', value ? 'true' : 'false');
  }

  static Future<bool> getPresensiOpenCached() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    return box.get('presensi_open') == 'true';
  }
  static Future<bool> tryAcquireFlushLock() async {
    final box = await Hive.openBox<String>(LocationBufferService._boxName);
    final raw = box.get('flush_lock');
    final now = DateTime.now();
    if (raw != null && raw.isNotEmpty) {
      try {
        final held = DateTime.parse(raw);
        if (now.difference(held) < const Duration(seconds: 30)) {
          return false;
        }
      } catch (_) {
        // Lock korup - timpa.
      }
    }
    await box.put('flush_lock', now.toIso8601String());
    return true;
  }

  static Future<void> releaseFlushLock() async {
    try {
      final box = await Hive.openBox<String>(LocationBufferService._boxName);
      await box.delete('flush_lock');
    } catch (_) {
      // Abaikan.
    }
  }

  /// Hapus titik tertentu (setelah batch-nya terkirim sukses).
  Future<void> removeByIds(Set<String> ids) async {
    _points.removeWhere((p) => ids.contains(p.id));
    await _persist();
  }

  // --- Batch pending -------------------------------------------------------

  Future<({String batchId, List<TrackPoint> points})?>
  readPendingBatch() async {
    final box = await _box();
    final raw = box.get('pending_batch');
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final locs = map['locations'] as List? ?? const [];
      return (
        batchId: map['batch_id'] as String,
        points: [
          for (final e in locs)
            TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
      );
    } catch (_) {
      await box.delete('pending_batch');
      return null;
    }
  }

  Future<void> savePendingBatch(String batchId, List<TrackPoint> points) async {
    final box = await _box();
    await box.put(
      'pending_batch',
      jsonEncode({
        'batch_id': batchId,
        'locations': [for (final p in points) p.toJson()],
      }),
    );
  }

  Future<void> clearPendingBatch() async {
    final box = await _box();
    await box.delete('pending_batch');
  }

  Future<void> dispose() async {
    stop();
    // Box dibiarkan terbuka — Hive menangani lifecycle global.
  }
}
