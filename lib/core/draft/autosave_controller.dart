import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/draft/draft_repository.dart';

/// Callback yang dipanggil saat autosave perlu membaca isi form terkini.
typedef FieldSnapshot = Map<String, dynamic> Function();

/// Callback untuk restore isi form dari draft.
typedef DraftRestorer = void Function(FormDraft draft);

/// Controller autosave draft form (Rencana §1.3).
///
/// Menangani:
/// - **Debounced on-change** — tunggu jeda ±800ms tanpa perubahan baru simpan.
/// - **Lifecycle save** — saat app masuk background, paksa simpan langsung.
/// - **Load** — saat form dibuka, cek draft tersimpan.
/// - **Clear** — saat submit berhasil / user pilih "Mulai Baru".
///
/// Tidak dibunggu menjadi mixin supaya bisa dipakai dari _any_ State
/// tanpa harus mengubah class hierarchy (karena banyak form sudah
/// ConsumerStatefulWidget dengan boilerplate sendiri).
///
/// **Cara pakai:**
/// ```dart
/// late final AutosaveController _autosave;
///
/// @override
/// void initState() {
///   super.initState();
///   _autosave = AutosaveController(
///     ref: ref,
///     draftKey: 'servis_ajuan_${widget.initialArmadaId ?? 'new'}',
///     formType: DraftFormType.servisAjuan,
///     currentFields: _snapshot,
///     onRestore: _restore,
///   );
///   _autosave.init();
/// }
/// ```
class AutosaveController extends WidgetsBindingObserver {
  AutosaveController({
    required this.ref,
    required this.draftKey,
    required this.formType,
    required this.currentFields,
    this.onRestore,
    this.duration = const Duration(milliseconds: 800),
  });

  final WidgetRef ref;
  final String draftKey;
  final DraftFormType formType;
  final FieldSnapshot currentFields;
  final DraftRestorer? onRestore;

  /// Jeda debounce antara perubahan field dan penyimpanan.
  final Duration duration;

  Timer? _timer;
  bool _initialized = false;

  /// Dipanggil dari `initState()` atau setelah field form siap.
  void init() {
    WidgetsBinding.instance.addObserver(this);
    _initialized = true;
  }

  /// Panggil dari `dispose()` supaya listener lifecycle terlepas.
  void dispose() {
    _timer?.cancel();
    if (_initialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  /// Dipanggil dari `didChangeAppLifecycleState(AppLifecycleState.paused)`
  /// — atau setiap kali perlu flush pending sekarang.
  void flush() {
    _timer?.cancel();
    _save();
  }

  /// Dipanggil setiap field berubah untuk memicu debounce.
  void onFieldChanged() {
    _timer?.cancel();
    _timer = Timer(duration, _save);
  }

  // ── Internal ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_initialized) return;
    final repo = ref.read(draftRepositoryProvider);
    final fields = currentFields();
    await repo.save(
      draftKey: draftKey,
      formType: formType,
      fieldsJson: fields,
    );
  }

  /// Load draft dan panggil [onRestore] jika ditemukan.
  Future<bool> load() async {
    final repo = ref.read(draftRepositoryProvider);
    final draft = await repo.load(draftKey);
    if (draft != null && onRestore != null) {
      onRestore!(draft);
      return true;
    }
    return false;
  }

  /// Hapus draft (dipanggil setelah submit berhasil atau user pilih
  /// "Mulai Baru").
  Future<void> clear() async {
    _timer?.cancel();
    final repo = ref.read(draftRepositoryProvider);
    await repo.delete(draftKey);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      flush();
    }
  }
}