import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import 'checklist_major_model.dart';

/// Penyimpanan lokal snapshot "berangkat" Checklist Major (Hive).
///
/// Berfungsi sebagai basis perbandingan mode "kembali" — tidak ada GET
/// riwayat checklist-major di API, jadi kondisi berangkat dicatat di
/// perangkat saat submit berangkat berhasil. Snapshot terbaru per armada.
class ChecklistMajorStore {
  ChecklistMajorStore._();

  static const _boxName = 'checklist_major_berangkat';

  static Future<Box<String>> _box() => Hive.openBox<String>(_boxName);

  /// Snapshot berangkat paling baru untuk [armadaId] (null bila belum ada).
  static Future<MajorChecklistSnapshot?> loadBerangkat(String armadaId) async {
    final raw = (await _box()).get(armadaId);
    if (raw == null) return null;
    try {
      return MajorChecklistSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  /// Menyimpan snapshot berangkat terbaru untuk [armadaId].
  static Future<void> saveBerangkat(MajorChecklistSnapshot snapshot) async {
    await (await _box()).put(snapshot.armadaId, jsonEncode(snapshot.toJson()));
  }

  /// Menghapus snapshot berangkat untuk [armadaId] (uji / reset).
  static Future<void> clear(String armadaId) async {
    await (await _box()).delete(armadaId);
  }
}