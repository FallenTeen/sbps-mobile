import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Jenis form yang mendukung autosave draft (Rencana §1.2).
///
/// Dipakai sebagai bagian dari `draftKey` + meta draft supaya restore
/// bisa meneruskan ke instan form yang benar.
enum DraftFormType {
  servisAjuan,
  formulirLapangan,
  dokumentasi,
  workshopSelesai,
  checklist,
  checklistMajor,
  slumpTest,
  ujiTekan,
  inventoryOpname,
  ritaseInput;

  String get label => switch (this) {
    servisAjuan => 'Ajuan Servis',
    formulirLapangan => 'Formulir Lapangan',
    dokumentasi => 'Dokumentasi Produksi',
    workshopSelesai => 'Workshop — Selesaikan',
    checklist => 'Checklist',
    checklistMajor => 'Checklist Major',
    slumpTest => 'Slump Test',
    ujiTekan => 'Uji Tekan',
    inventoryOpname => 'Inventory Opname',
    ritaseInput => 'Input Muatan',
  };
}

/// Satu draft form yang belum disubmit, tersimpan lokal di Hive box
/// `form_drafts` (terpisah dari box outbox — draft ≠ outbox).
///
/// Hanya menyimpan referensi path foto, bukan binary — file tetap di
/// storage device (konsisten dengan pola compress-then-reference di outbox).
class FormDraft {
  const FormDraft({
    required this.draftKey,
    required this.formType,
    required this.fieldsJson,
    this.photoLocalPaths = const [],
    this.currentStep,
    required this.savedAt,
    required this.expiresAt,
  });

  /// Identifier unik per konteks form, kombinasi `formType` + `contextId`
  /// (mis. `servis_ajuan_{armadaId}`, `workshop_selesai_{jobId}`).
  final String draftKey;
  final DraftFormType formType;
  final Map<String, dynamic> fieldsJson;
  final List<String> photoLocalPaths;
  final int? currentStep;
  final DateTime savedAt;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  FormDraft copyWith({
    Map<String, dynamic>? fieldsJson,
    List<String>? photoLocalPaths,
    int? currentStep,
    DateTime? savedAt,
  }) {
    return FormDraft(
      draftKey: draftKey,
      formType: formType,
      fieldsJson: fieldsJson ?? this.fieldsJson,
      photoLocalPaths: photoLocalPaths ?? this.photoLocalPaths,
      currentStep: currentStep ?? this.currentStep,
      savedAt: savedAt ?? this.savedAt,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'draftKey': draftKey,
    'formType': formType.name,
    'fieldsJson': fieldsJson,
    'photoLocalPaths': photoLocalPaths,
    'currentStep': currentStep,
    'savedAt': savedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  static FormDraft? fromJson(String raw) {
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final savedAt = DateTime.parse(map['savedAt'] as String);
      final expiresAt = DateTime.parse(map['expiresAt'] as String);
      final formType = DraftFormType.values.firstWhere(
        (t) => t.name == map['formType'],
      );
      return FormDraft(
        draftKey: map['draftKey'] as String,
        formType: formType,
        fieldsJson: Map<String, dynamic>.from(map['fieldsJson'] as Map),
        photoLocalPaths: (map['photoLocalPaths'] as List)
            .map((e) => e as String)
            .toList(),
        currentStep: map['currentStep'] as int?,
        savedAt: savedAt,
        expiresAt: expiresAt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Penyimpanan draft form (Hive box `form_drafts`).
///
/// CRUD mirror pola [OutboxRepository] yang sudah ada — draft disimpan
/// sebagai string JSON ber-key `draftKey`. Draft bersifat lokal per device,
/// tidak disinkron ke server.
class DraftRepository {
  DraftRepository({String boxName = 'form_drafts'}) : _boxName = boxName;

  final String _boxName;

  /// Umur maksimum draft dalam hari sebelum dianggap basi & dibersihkan.
  static const int defaultExpiryDays = 3;

  Box<String>? _box;
  Future<Box<String>>? _opening;

  Future<Box<String>> _ensureOpen() {
    final existing = _box;
    if (existing != null && existing.isOpen) return Future.value(existing);
    return _opening ??= Hive.openBox<String>(_boxName).then((box) {
      _box = box;
      return box;
    });
  }

  /// Draft paling baru untuk [draftKey], null jika tidak ada.
  Future<FormDraft?> load(String draftKey) async {
    final box = await _ensureOpen();
    final raw = box.get(draftKey);
    if (raw == null) return null;
    final draft = FormDraft.fromJson(raw);
    if (draft == null) {
      await box.delete(draftKey);
      return null;
    }
    return draft;
  }

  /// Simpan / perbarui draft. [expiresAt] dihitung dari [savedAt] +
  /// [DraftRepository.defaultExpiryDays].
  Future<void> save({
    required String draftKey,
    required DraftFormType formType,
    required Map<String, dynamic> fieldsJson,
    List<String> photoLocalPaths = const [],
    int? currentStep,
    DateTime? savedAt,
  }) async {
    final now = savedAt ?? DateTime.now();
    final draft = FormDraft(
      draftKey: draftKey,
      formType: formType,
      fieldsJson: fieldsJson,
      photoLocalPaths: photoLocalPaths,
      currentStep: currentStep,
      savedAt: now,
      expiresAt: now.add(const Duration(days: defaultExpiryDays)),
    );
    final box = await _ensureOpen();
    await box.put(draftKey, jsonEncode(draft.toJson()));
  }

  /// Hapus draft — dipanggil setelah submit berhasil, saat user memilih
  /// "Mulai Baru", atau saat expired.
  Future<void> delete(String draftKey) async {
    final box = await _ensureOpen();
    await box.delete(draftKey);
  }

  /// Bersihkan semua draft yang kedaluwarsa (housekeeping — dipanggil saat
  /// app start). Menghindari penumpukan draft lama + file foto yang
  /// direferensikan draft.
  Future<int> cleanupExpired() async {
    final box = await _ensureOpen();
    var removed = 0;
    for (final key in box.keys.toList()) {
      final draft = FormDraft.fromJson(box.get(key) ?? '');
      if (draft == null || draft.isExpired) {
        await box.delete(key);
        removed++;
      }
    }
    return removed;
  }

  /// Semua draft saat ini (untuk debugging / indikator jumlah).
  Future<List<FormDraft>> allDrafts() async {
    final box = await _ensureOpen();
    final drafts = <FormDraft>[];
    for (final raw in box.values) {
      final draft = FormDraft.fromJson(raw);
      if (draft != null && !draft.isExpired) drafts.add(draft);
    }
    drafts.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return drafts;
  }
}

final draftRepositoryProvider = Provider<DraftRepository>(
  (ref) => DraftRepository(),
);
