import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'ritase_model.dart';

/// Penyimpanan persistensi record muatan (Hive box `ritase_draft`).
///
/// Berbeda dari outbox: store ini menyimpan SELURUH record hari ini
/// (termasuk yang sudah synced) supaya index "Muatan Hari Ini" tetap
/// menjawab berapa record / berapa rit / unit terkait / status tiap record.
/// Draft TIDAK dihapus saat keluar dari screen — hanya hilang bila user
/// menghapusnya atau session diganti hari.
class RitaseDraftStore {
  RitaseDraftStore._();

  static const _boxName = 'ritase_draft';
  static const _key = 'records';

  static Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  static Future<List<RitaseRecord>> loadRecords() async {
    final raw = (await _box()).get(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded)
          if (e is Map)
            RitaseRecord.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRecords(List<RitaseRecord> records) async {
    final encoded = jsonEncode([for (final r in records) r.toJson()]);
    await (await _box()).put(_key, encoded);
  }

  static Future<void> clear() async {
    await (await _box()).delete(_key);
  }
}