import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../core/app_config.dart';
import '../../core/location_service.dart';
import 'models.dart';

/// Buffer titik GPS untuk Live Tracking (Fase A2.4).
///
/// Aturan perekaman: setiap berpindah >= 50 meter ATAU tiap ~60 detik
/// (mana yang lebih dulu). Berhenti mengumpulkan otomatis setelah jam
/// cutoff ([AppConfig.trackingCutoffHour], default 18:00).
///
/// Persistensi: Hive box `tracking_buffer` —
/// - key `points`: JSON list seluruh titik belum terkirim;
/// - key `pending_batch`: batch yang sedang menunggu keberhasilan kirim,
///   berisi `batch_id` + isi persis — dipakai ULANG pada retry agar
///   backend idempotent dan batch tidak pernah dipecah/digabung ulang.
class LocationBufferService {
  static const _boxName = 'tracking_buffer';
  static const _maxPoints = 5000;

  final LocationService _location;

  StreamSubscription<Position>? _positionSub;
  Timer? _fallbackTimer;
  Position? _lastSeen;
  DateTime? _lastStoredAt;
  bool _running = false;

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
    await _pruneStale();
  }

  /// Mulai perekaman. Return pesan kesalahan bila gagal (izin/GPS mati),
  /// null bila sukses berjalan.
  Future<String?> start() async {
    if (_running) return null;
    if (DateTime.now().hour >= AppConfig.trackingCutoffHour) {
      return 'Tracking sudah melewati jam cutoff.';
    }
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
    // simpan posisi terakhir tiap 60 detik bila ada yang baru.
    _fallbackTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final last = _lastSeen;
      final stored = _lastStoredAt;
      if (last == null) return;
      if (stored != null &&
          DateTime.now().difference(stored) < const Duration(seconds: 55)) {
        return;
      }
      _onPosition(last);
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
    if (DateTime.now().hour >= AppConfig.trackingCutoffHour) return;
    _lastSeen = position;
    _lastStoredAt = DateTime.now();
    _addPoint(TrackPoint(
      lat: position.latitude,
      lng: position.longitude,
      timestamp: position.timestamp.toLocal(),
    ));
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
    await box.put(
      'points',
      jsonEncode([for (final p in _points) p.toJson()]),
    );
  }

  /// Buang titik dari hari sebelumnya (sisa offline semalam) — server
  /// tidak menyimpannya lagi, jadi tidak ada gunanya dikirim ulang.
  Future<void> _pruneStale() async {
    final todayStart = DateTime.now();
    final midnight =
        DateTime(todayStart.year, todayStart.month, todayStart.day);
    final before = _points.length;
    _points.removeWhere((p) => p.timestamp.isBefore(midnight));
    if (_points.length != before) await _persist();
  }

  /// Ambil salinan titik yang belum masuk batch pending.
  List<TrackPoint> snapshot() => List.unmodifiable(_points);

  /// Hapus titik tertentu (setelah batch-nya terkirim sukses).
  Future<void> removeByIds(Set<String> ids) async {
    _points.removeWhere((p) => ids.contains(p.id));
    await _persist();
  }

  // --- Batch pending -------------------------------------------------------

  Future<({String batchId, List<TrackPoint> points})?> readPendingBatch() async {
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
    await box.put('pending_batch', jsonEncode({
      'batch_id': batchId,
      'locations': [for (final p in points) p.toJson()],
    }));
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
