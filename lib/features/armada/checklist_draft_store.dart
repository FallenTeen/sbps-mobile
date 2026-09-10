import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Autosave draft checklist harian per unit per hari (Hive).
class ChecklistDraftStore {
  ChecklistDraftStore._();

  static const _boxName = 'checklist_draft';

  static Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  static String _key(String armadaId, {required bool isAkhir}) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${isAkhir ? 'akhir' : 'pagi'}:$armadaId:$date';
  }

  static Future<Map<String, dynamic>?> load(
    String armadaId, {
    required bool isAkhir,
  }) async {
    final raw = (await _box()).get(_key(armadaId, isAkhir: isAkhir));
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    String armadaId, {
    required bool isAkhir,
    required Map<String, dynamic> data,
  }) async {
    await (await _box()).put(
      _key(armadaId, isAkhir: isAkhir),
      jsonEncode(data),
    );
  }

  static Future<void> clear(String armadaId, {required bool isAkhir}) async {
    await (await _box()).delete(_key(armadaId, isAkhir: isAkhir));
  }

  static Future<bool> isAkhirSubmitted(String armadaId) async {
    final data = await load(armadaId, isAkhir: true);
    return data?['submitted'] == true;
  }

  static Future<void> markAkhirSubmitted(String armadaId) async {
    final existing = await load(armadaId, isAkhir: true) ?? {};
    existing['submitted'] = true;
    await save(armadaId, isAkhir: true, data: existing);
  }
}
