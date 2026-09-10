import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Generic read-cache layer untuk response GET.
///
/// Pola: *cache-first-then-refresh* — tampilkan data dari Hive langsung
/// (instant, walau offline), lalu di background coba fetch terbaru dan
/// update cache+UI kalau online.
///
/// Digunakan untuk: titik-aktif, titik-map, assignments, presensi/hari-ini,
/// formulir/hari-ini, master/armada, armada/checklist-hari-ini, armada/helper,
/// servis-armada (list), master/mesin, master/produk, master/bahan-baku.
class CacheService {
  CacheService({String boxName = 'api_cache'}) : _boxName = boxName;

  final String _boxName;
  Box<String>? _box;

  Future<Box<String>> _ensureOpen() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Ambil data dari cache (sinkron, tanpa network).
  Future<T?> getCached<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final box = await _ensureOpen();
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Simpan data ke cache.
  Future<void> setCached<T>(
    String key,
    T data,
    String Function(T) toJson,
  ) async {
    final box = await _ensureOpen();
    final entry = jsonEncode({
      'data': jsonDecode(toJson(data)),
      'cached_at': DateTime.now().toIso8601String(),
    });
    await box.put(key, entry);
  }

  /// Pattern cache-first-then-refresh:
  /// 1. Return cached data segera (kalau ada).
  /// 2. Fetch dari network di background.
  /// 3. Update cache + return fresh data.
  ///
  /// [onCached] dipanggil dengan data cache (untuk display awal).
  /// [onFresh] dipanggil dengan data fresh dari network (untuk update UI).
  Future<T?> cacheFirstThenRefresh<T>({
    required String cacheKey,
    required Future<T> Function() fetcher,
    required T Function(Map<String, dynamic>) fromJson,
    required String Function(T) toJson,
    void Function(T)? onCached,
    void Function(T)? onFresh,
  }) async {
    // 1. Coba cache dulu.
    final cached = await getCached<T>(cacheKey, fromJson);
    if (cached != null) {
      onCached?.call(cached);
    }

    // 2. Fetch dari network.
    try {
      final fresh = await fetcher();
      await setCached(cacheKey, fresh, toJson);
      onFresh?.call(fresh);
      return fresh;
    } catch (_) {
      // Network gagal — kembalikan cache kalau ada.
      return cached;
    }
  }

  /// Hapus satu entry cache.
  Future<void> invalidate(String key) async {
    final box = await _ensureOpen();
    await box.delete(key);
  }

  /// Hapus semua cache.
  Future<void> clearAll() async {
    final box = await _ensureOpen();
    await box.clear();
  }
}
