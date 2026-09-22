import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../core/armada_jenis.dart';
import '../../core/draft/draft_repository.dart';
import '../../core/formatters.dart';
import '../../core/json_num.dart';
import '../../core/outbox/pending_action.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/submit_spinner.dart';
import '../presensi/presensi_providers.dart';
import 'armada_providers.dart';
import 'models/armada.dart';
import 'ritase_draft_store.dart';
import 'ritase_model.dart';

/// Muatan Hari Ini — hub multi-record ritase (Section 21.4) versi Phase 08.
///
/// Index menjawab: berapa record, berapa total rit (per satuan, tidak
/// dijumlah menggabungkan satuan yang berbeda), unit terkait, dan status
/// tiap record (Draft / Menunggu sinkron / Dikirim / Gagal).
///
/// Record dapat dibuat, diedit, dihapus, disimpan sebagai draft (persisten —
/// keluar layar tidak menghapus), direview, dikirim per record, dan di-retry.
/// Submit berjalan per record (sequential) sehingga partial failure terlihat
/// per record. Queued ≠ server success (badge "Menunggu sinkron" terpisah
/// dari "Dikirim").
class RitaseInputScreen extends ConsumerStatefulWidget {
  const RitaseInputScreen({super.key});

  @override
  ConsumerState<RitaseInputScreen> createState() => _RitaseInputScreenState();
}

class _RitaseInputScreenState extends ConsumerState<RitaseInputScreen> {
  static const _uuid = Uuid();
  static const _legacyDraftKey = 'ritase_input';

  List<RitaseRecord> _records = [];
  bool _loaded = false;
  bool _submittingAll = false;
  final Set<String> _syncingIds = {};

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      var records = await RitaseDraftStore.loadRecords();
      if (records.isEmpty) {
        records = await _migrateLegacyDraft();
      }
      if (!mounted) return;
      setState(() {
        _records = records;
        _loaded = true;
      });
      _reconcile();
    } catch (_) {}
  }

  /// Migrasi draft lama (generic `ritase_input`) ke store baru supaya draft
  /// yang sudah ada tidak hilang saat upgrade.
  Future<List<RitaseRecord>> _migrateLegacyDraft() async {
    try {
      final legacy = await ref
          .read(draftRepositoryProvider)
          .load(_legacyDraftKey);
      if (legacy == null) return [];
      final rawRecords = legacy.fieldsJson['records'];
      if (rawRecords is! List || rawRecords.isEmpty) return [];

      final migrated = <RitaseRecord>[];
      for (final e in rawRecords) {
        if (e is! Map) continue;
        final map = Map<String, dynamic>.from(e);
        final index = parseInt(map['index']);
        final jumlah = parseInt(map['jumlah']);
        final armadaId = map['armada_id']?.toString();
        if (index == null || jumlah == null || armadaId == null) continue;
        migrated.add(
          RitaseRecord(
            id: _uuid.v4(),
            index: index,
            armadaId: armadaId,
            jumlah: jumlah,
            satuan: (map['satuan'] as String?) ?? 'rit',
            catatan: map['catatan']?.toString(),
            odoPerTrip: parseNum(map['odo_per_trip']),
            createdAt: DateTime.now(),
            clientUuid: _uuid.v4(),
            idempotencyKey: _uuid.v4(),
          ),
        );
      }
      if (migrated.isNotEmpty) {
        await RitaseDraftStore.saveRecords(migrated);
        await ref.read(draftRepositoryProvider).delete(_legacyDraftKey);
      }
      return migrated;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRecords() async {
    try {
      await RitaseDraftStore.saveRecords(_records);
    } catch (_) {
      // Penyimpanan best-effort; jangan gagalkan UX.
    }
  }

  /// Reconcile status record terhadap isi outbox: action yang sudah dihapus
  /// dari outbox = diterima server → tandai `synced`.
  Future<void> _reconcile() async {
    if (!_loaded) return;
    try {
      final actions = await ref.read(outboxRepositoryProvider).pendingActions();
      final byUuid = <String, PendingStatus>{
        for (final a in actions) a.clientUuid: a.status,
      };
      final updated = <RitaseRecord>[
        for (final r in _records) reconcileRecordStatus(r, byUuid),
      ];
      var changed = false;
      for (var i = 0; i < _records.length; i++) {
        if (updated[i] != _records[i]) {
          changed = true;
          break;
        }
      }
      if (changed) {
        setState(() => _records = updated);
        await _saveRecords();
      }
    } catch (_) {}
  }

  int get _nextIndex => _records.isEmpty
      ? 1
      : _records.map((r) => r.index).reduce((a, b) => a > b ? a : b) + 1;

  // -------------------------------------------------------------------------
  // Create / edit / delete
  // -------------------------------------------------------------------------

  Future<void> _openFormSheet({
    RitaseRecord? existing,
    required List<ArmadaSaya> armadaList,
  }) async {
    final result = await showModalBottomSheet<RitaseRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RecordFormSheet(
        armadaList: armadaList,
        existing: existing,
        nextIndex: _nextIndex,
      ),
    );
    if (result == null || !mounted) return;
    _upsertRecord(existing, result);
  }

  void _upsertRecord(RitaseRecord? existing, RitaseRecord incoming) {
    if (existing == null) {
      setState(() => _records = [..._records, incoming]);
    } else {
      // Saat edit record yang sudah diantre, batal antrean lama dulu supaya
      // tidak ada payload yang berubah dikirim diam-diam.
      if (existing.status == RitaseRecordStatus.queued ||
          existing.status == RitaseRecordStatus.failed) {
        unawaited(_cancelPendingByClientUuid(existing.clientUuid));
      }
      final idx = _records.indexWhere((r) => r.id == existing.id);
      if (idx >= 0) {
        setState(() => _records[idx] = incoming);
      }
    }
    _saveRecords();
  }

  Future<void> _deleteRecord(RitaseRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Muatan #${record.index}?'),
        content: const Text('Data muatan ini akan dihapus dari perangkat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    HapticFeedback.lightImpact();
    if (record.status == RitaseRecordStatus.queued ||
        record.status == RitaseRecordStatus.failed) {
      unawaited(_cancelPendingByClientUuid(record.clientUuid));
    }
    setState(() => _records.removeWhere((r) => r.id == record.id));
    _saveRecords();
  }

  /// Buang aksi outbox yang masih mengganggu (antre/gagal) dengan
  /// mencocokkan `client_uuid` — mencegah pengiriman payload lama.
  Future<void> _cancelPendingByClientUuid(String clientUuid) async {
    if (clientUuid.isEmpty) return;
    try {
      final actions = await ref.read(outboxRepositoryProvider).pendingActions();
      for (final a in actions) {
        if (a.clientUuid == clientUuid) {
          await ref.read(outboxRepositoryProvider).remove(a.id);
        }
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------------------
  // Submit per record (sequential — partial failure terlihat per record)
  // -------------------------------------------------------------------------

  Future<void> _submitRecords(List<RitaseRecord> targets) async {
    var delivered = 0;
    var queued = 0;
    var failed = 0;
    String? firstFail;

    for (final record in targets) {
      setState(() => _syncingIds.add(record.id));
      try {
        final result = await ref
            .read(armadaRepositoryProvider)
            .submitRitase(
              armadaId: record.armadaId,
              jumlahRit: record.jumlah,
              satuanVolume: record.satuanVolume,
              titikId: record.titikId,
              proyekId: record.proyekId,
              catatan: record.catatan,
              odoPerTrip: record.odoPerTrip,
              clientUuid: record.clientUuid,
              idempotencyKey: record.idempotencyKey,
            );
        final idx = _records.indexWhere((r) => r.id == record.id);
        if (idx >= 0) {
          if (result.delivered) {
            _records[idx] = _records[idx].copyWith(
              status: RitaseRecordStatus.synced,
              clearError: true,
            );
            delivered++;
          } else if (result.permanentlyFailed) {
            _records[idx] = _records[idx].copyWith(
              status: RitaseRecordStatus.failed,
              errorMessage: result.errorMessage,
            );
            failed++;
            firstFail ??= result.errorMessage;
          } else {
            _records[idx] = _records[idx].copyWith(
              status: RitaseRecordStatus.queued,
            );
            queued++;
          }
        }
      } on ApiException catch (e) {
        failed++;
        firstFail ??= e.message;
        final idx = _records.indexWhere((r) => r.id == record.id);
        if (idx >= 0) {
          _records[idx] = _records[idx].copyWith(
            status: RitaseRecordStatus.failed,
            errorMessage: e.message,
          );
        }
      } catch (e) {
        failed++;
        final msg = friendlyErrorMessage(
          e,
          fallback: 'Terjadi kesalahan sistem. Coba lagi.',
        );
        firstFail ??= msg;
        final idx = _records.indexWhere((r) => r.id == record.id);
        if (idx >= 0) {
          _records[idx] = _records[idx].copyWith(
            status: RitaseRecordStatus.failed,
            errorMessage: msg,
          );
        }
      } finally {
        if (mounted) {
          setState(() => _syncingIds.remove(record.id));
        }
      }
    }

    await _saveRecords();
    if (mounted) {
      if (targets.length == 1) {
        _showSubmitSummary(
          targets.first.index,
          delivered,
          queued,
          failed,
          firstFail,
        );
      }
      // Riwayat tab mengambil dari server — segarkan setelah ada yang terkirim.
      if (delivered > 0) ref.invalidate(ritaseRiwayatProvider);
    }
  }

  Future<void> _submitAll() async {
    final toSend = _records
        .where(
          (r) =>
              r.status == RitaseRecordStatus.draft ||
              r.status == RitaseRecordStatus.failed,
        )
        .toList();
    if (toSend.isEmpty || _submittingAll) return;

    HapticFeedback.mediumImpact();
    AnalyticsService.ritaseSubmitAll(toSend.length);
    setState(() => _submittingAll = true);
    var delivered = 0;
    var queued = 0;
    var failed = 0;
    String? firstFail;

    try {
      for (final record in toSend) {
        setState(() => _syncingIds.add(record.id));
        try {
          final result = await ref
              .read(armadaRepositoryProvider)
              .submitRitase(
                armadaId: record.armadaId,
                jumlahRit: record.jumlah,
                satuanVolume: record.satuanVolume,
                titikId: record.titikId,
                proyekId: record.proyekId,
                catatan: record.catatan,
                odoPerTrip: record.odoPerTrip,
                clientUuid: record.clientUuid,
                idempotencyKey: record.idempotencyKey,
              );
          final idx = _records.indexWhere((r) => r.id == record.id);
          if (idx >= 0) {
            if (result.delivered) {
              _records[idx] = _records[idx].copyWith(
                status: RitaseRecordStatus.synced,
                clearError: true,
              );
              delivered++;
            } else if (result.permanentlyFailed) {
              _records[idx] = _records[idx].copyWith(
                status: RitaseRecordStatus.failed,
                errorMessage: result.errorMessage,
              );
              failed++;
              firstFail ??= result.errorMessage;
            } else {
              _records[idx] = _records[idx].copyWith(
                status: RitaseRecordStatus.queued,
              );
              queued++;
            }
          }
        } on ApiException catch (e) {
          failed++;
          firstFail ??= e.message;
          final idx = _records.indexWhere((r) => r.id == record.id);
          if (idx >= 0) {
            _records[idx] = _records[idx].copyWith(
              status: RitaseRecordStatus.failed,
              errorMessage: e.message,
            );
          }
        } catch (e) {
          failed++;
          final msg = friendlyErrorMessage(
            e,
            fallback: 'Terjadi kesalahan sistem. Coba lagi.',
          );
          firstFail ??= msg;
          final idx = _records.indexWhere((r) => r.id == record.id);
          if (idx >= 0) {
            _records[idx] = _records[idx].copyWith(
              status: RitaseRecordStatus.failed,
              errorMessage: msg,
            );
          }
        } finally {
          if (mounted) setState(() => _syncingIds.remove(record.id));
        }
      }
    } finally {
      if (mounted) setState(() => _submittingAll = false);
      await _saveRecords();
      if (mounted && delivered > 0) ref.invalidate(ritaseRiwayatProvider);
    }

    if (mounted) {
      HapticFeedback.lightImpact();
      if (failed == 0 && queued == 0) {
        _snack('$delivered muatan berhasil dikirim ke server.');
      } else if (failed == 0 && delivered > 0) {
        _snack(
          '$delivered muatan terkirim, $queued disimpan di antrean offline.',
        );
      } else if (failed == 0) {
        _snack(
          '$queued muatan tersimpan di antrean (akan disinkronkan saat online).',
        );
      } else {
        _snack('Gagal mengirim: $firstFail');
      }
    }
  }

  void _showSubmitSummary(
    int index,
    int delivered,
    int queued,
    int failed,
    String? errorMsg,
  ) {
    if (failed > 0) {
      _snack(
        'Muatan #$index gagal: ${errorMsg ?? "Periksa koneksi lalu coba lagi"}',
      );
    } else if (queued > 0) {
      _snack('Muatan #$index tersimpan di perangkat (antrean sinkronisasi).');
    } else {
      _snack('Muatan #$index berhasil dikirim ke server.');
    }
  }

  Future<void> _retryRecord(RitaseRecord record) async {
    setState(() => _syncingIds.add(record.id));
    try {
      final actions = await ref.read(outboxRepositoryProvider).pendingActions();
      PendingAction? match;
      for (final a in actions) {
        if (a.clientUuid == record.clientUuid) {
          match = a;
          break;
        }
      }
      if (match != null) {
        if (match.status == PendingStatus.failed) {
          await ref.read(outboxRepositoryProvider).markPending(match.id);
          await ref
              .read(outboxSyncServiceProvider)
              .syncNow(ignoreBackoff: true);
          _snack('Percobaan ulang muatan #${record.index} dikirim.');
        } else {
          await ref
              .read(outboxSyncServiceProvider)
              .syncNow(ignoreBackoff: true);
          _snack('Sedang mencoba mengirim muatan #${record.index}...');
        }
      } else {
        // Aksi sudah hilang (kemungkinan sudah masuk server) — enqueue ulang.
        await _submitRecords([record]);
      }
    } catch (_) {
      _snack('Gagal mengirim ulang. Coba lagi.');
    } finally {
      if (mounted) setState(() => _syncingIds.remove(record.id));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingActionsProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reconcile());
    });

    final armadaAsync = ref.watch(armadaSayaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muatan Hari Ini'),
        actions: [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Gagal memuat data armada',
          subtitle:
              'Tidak dapat terhubung ke server.\nPeriksa koneksi internet lalu coba lagi.',
          actionLabel: 'Coba Lagi',
          onAction: () => ref.invalidate(armadaSayaProvider),
        ),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const AppEmptyState(
              icon: Icons.no_crash_outlined,
              title: 'Belum ada armada yang ditugaskan',
              subtitle:
                  'Hubungi admin untuk mendapatkan penugasan unit kendaraan.',
            );
          }
          final byId = {for (final a in armadaList) a.id: a};
          final summary = summaryRitase(_records);

          return Column(
            children: [
              _SummaryHeader(
                summary: summary,
                onAdd: () => _openFormSheet(armadaList: armadaList),
              ),
              Expanded(
                child: _records.isEmpty
                    ? AppEmptyState(
                        icon: Icons.add_box_outlined,
                        title: 'Belum ada muatan',
                        subtitle:
                            'Catat muatan/jam kerja unit Anda hari ini.\n'
                            'Draft tersimpan otomatis dan tidak hilang '
                            'saat Anda keluar layar.',
                        actionLabel: 'Tambah Muatan',
                        onAction: () => _openFormSheet(armadaList: armadaList),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _records.length,
                        itemBuilder: (context, i) {
                          final record = _records[i];
                          return _RecordCard(
                            record: record,
                            armada: byId[record.armadaId],
                            submitting:
                                _syncingIds.contains(record.id) ||
                                (_submittingAll &&
                                    record.status == RitaseRecordStatus.draft),
                            onEdit: () => _openFormSheet(
                              existing: record,
                              armadaList: armadaList,
                            ),
                            onDelete: () => _deleteRecord(record),
                            onReview: () => _openReviewSheet(record),
                            onSubmit: () => _submitRecords([record]),
                            onRetry: () => _retryRecord(record),
                          );
                        },
                      ),
              ),
              if (_records.isNotEmpty)
                _SubmitBar(
                  summary: summary,
                  submittingAll: _submittingAll,
                  onSendAll: _submitAll,
                ),
            ],
          );
        },
      ),
    );
  }

  void _openReviewSheet(RitaseRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReviewSheet(record: record),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary / index header
// ---------------------------------------------------------------------------

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.summary, required this.onAdd});

  final RitaseSummary summary;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final recordText = '${summary.recordCount} record';
    final unitText = '${summary.unitCount} unit';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: context.colors.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, size: 18, color: context.colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Muatan Hari Ini — $recordText • $unitText',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Baru'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Total per satuan — TIDAK dijumlah lintas satuan (tidak menyesatkan).
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final b in summary.bySatuan)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    '${b.total} ${b.satuan}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
              if (summary.bySatuan.isEmpty)
                Text(
                  'Belum ada muatan',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusDot(
                label: '${summary.draftCount} draft',
                color: Colors.blueGrey,
                show: summary.draftCount > 0,
              ),
              _StatusDot(
                label: '${summary.queuedCount} menunggu sinkron',
                color: Colors.amber,
                show: summary.queuedCount > 0,
              ),
              _StatusDot(
                label: '${summary.failedCount} gagal',
                color: context.colors.error,
                show: summary.failedCount > 0,
              ),
              _StatusDot(
                label: '${summary.syncedCount} terkirim',
                color: context.colors.success,
                show: summary.syncedCount > 0,
              ),
              const Spacer(),
              if (summary.hasPending)
                Text(
                  'Belum 100% di server',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.warning,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.label,
    required this.color,
    required this.show,
  });

  final String label;
  final Color color;
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Record card
// ---------------------------------------------------------------------------

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.armada,
    required this.submitting,
    required this.onEdit,
    required this.onDelete,
    required this.onReview,
    required this.onSubmit,
    required this.onRetry,
  });

  final RitaseRecord record;
  final ArmadaSaya? armada;
  final bool submitting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReview;
  final VoidCallback onSubmit;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final plat = armada?.platNomor ?? record.armadaPlat ?? '-';
    final jenis = _labelJenis(armada?.jenis ?? record.armadaJenis);
    final editable = record.isLocalEditable;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${record.index}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plat,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: record.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${record.jumlah} ${record.satuan} — $jenis'
              '${record.isAlatBerat ? ' • HM' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
            if (record.catatan != null &&
                record.catatan!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                record.catatan!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (record.odoPerTrip != null) ...[
              const SizedBox(height: 4),
              Text(
                'ODO/trip: ${fmtOdo(record.odoPerTrip!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textTertiary,
                ),
              ),
            ],
            if (record.status == RitaseRecordStatus.failed &&
                record.errorMessage != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.errorMessage!,
                  style: TextStyle(fontSize: 12, color: context.colors.error),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (record.status == RitaseRecordStatus.queued)
                  _ActionText(
                    icon: Icons.cloud_upload_outlined,
                    label: 'Otomatis saat online',
                    color: Colors.amber.shade800,
                  ),
                if (editable &&
                    (record.status == RitaseRecordStatus.draft ||
                        record.status == RitaseRecordStatus.failed))
                  FilledButton.icon(
                    onPressed: submitting ? null : onSubmit,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: submitting
                        ? const SubmitSpinner(size: 14)
                        : const Icon(Icons.send, size: 15),
                    label: Text(
                      record.status == RitaseRecordStatus.failed
                          ? 'Kirim Ulang'
                          : 'Kirim',
                    ),
                  ),
                if (record.status == RitaseRecordStatus.failed)
                  OutlinedButton.icon(
                    onPressed: submitting ? null : onRetry,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.refresh, size: 15),
                    label: const Text('Coba Lagi'),
                  ),
                _TextAction(label: 'Detail', onTap: onReview),
                if (editable) _TextAction(label: 'Edit', onTap: onEdit),
                if (editable)
                  _TextAction(
                    label: 'Hapus',
                    onTap: onDelete,
                    color: context.colors.error,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline text-link kecil (seperti link) untuk aksi per record.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? context.colors.primary,
          ),
        ),
      ),
    );
  }
}

class _ActionText extends StatelessWidget {
  const _ActionText({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RitaseRecordStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      RitaseRecordStatus.draft => (Colors.blueGrey, Icons.edit_note),
      RitaseRecordStatus.queued => (
        Colors.amber.shade800,
        Icons.cloud_upload_outlined,
      ),
      RitaseRecordStatus.synced => (context.colors.success, Icons.check_circle),
      RitaseRecordStatus.failed => (context.colors.error, Icons.error_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom submit bar
// ---------------------------------------------------------------------------

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.summary,
    required this.submittingAll,
    required this.onSendAll,
  });

  final RitaseSummary summary;
  final bool submittingAll;
  final VoidCallback onSendAll;

  @override
  Widget build(BuildContext context) {
    final toSend = summary.draftCount + summary.failedCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (summary.queuedCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${summary.queuedCount} menunggu sinkron — terkirim otomatis '
                'saat online.',
                style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: BouncingButton(
              onPressed: toSend == 0 || submittingAll ? null : onSendAll,
              child: FilledButton.icon(
                onPressed: toSend == 0 || submittingAll ? null : onSendAll,
                icon: submittingAll
                    ? const SubmitSpinner(size: 18)
                    : const Icon(Icons.send, size: 18),
                label: Text(
                  submittingAll
                      ? 'Mengirim...'
                      : toSend > 0
                      ? 'Kirim Semua Muatan ($toSend)'
                      : summary.queuedCount > 0
                      ? 'Sedang menunggu sinkron otomatis'
                      : 'Semua muatan terkirim',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _labelJenis(String? jenis) => labelJenisArmada(jenis, fallback: 'Unit');

/// Format ODO/HM untuk tampilan (ribuan bertitik, bulat).
String fmtOdo(double n) => fmtRibuan(n % 1 == 0 ? n.toInt() : n.round());

// ---------------------------------------------------------------------------
// Create / edit form (bottom sheet)
// ---------------------------------------------------------------------------

class _RecordFormSheet extends ConsumerStatefulWidget {
  const _RecordFormSheet({
    required this.armadaList,
    required this.nextIndex,
    this.existing,
  });

  final List<ArmadaSaya> armadaList;
  final int nextIndex;
  final RitaseRecord? existing;

  @override
  ConsumerState<_RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends ConsumerState<_RecordFormSheet> {
  static const _uuid = Uuid();
  static const _satuanOptions = <String>[
    'rit',
    'trip',
    'ton',
    'm³',
    'kg',
    'ltr',
    'unit',
    'kloter',
  ];

  final _jumlahCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  ArmadaSaya? _armada;
  String _satuan = 'rit';
  bool _isSingleUnit = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _isSingleUnit = widget.armadaList.length == 1;
    if (existing != null) {
      final armada = _findArmada(existing.armadaId);
      _armada = armada;
      _jumlahCtrl.text = existing.jumlah.toString();
      _catatanCtrl.text = existing.catatan ?? '';
      _satuan = existing.satuan;
      if (existing.odoPerTrip != null) {
        _odoCtrl.text = existing.odoPerTrip.toString();
      }
    } else if (_isSingleUnit) {
      _armada = widget.armadaList.first;
      final odo = widget.armadaList.first.odoTerkini;
      if (odo != null) _odoCtrl.text = odo.toString();
    }
  }

  ArmadaSaya? _findArmada(String id) {
    for (final a in widget.armadaList) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  void dispose() {
    _jumlahCtrl.dispose();
    _catatanCtrl.dispose();
    _odoCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final armada = _armada;
    if (armada == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih kendaraan dulu')));
      return;
    }
    final jumlah = int.tryParse(_jumlahCtrl.text.trim());
    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah muatan harus angka positif')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final existing = widget.existing;
    final now = DateTime.now();
    final record = RitaseRecord(
      id: existing?.id ?? _uuid.v4(),
      index: existing?.index ?? widget.nextIndex,
      armadaId: armada.id,
      armadaPlat: armada.platNomor,
      armadaJenis: armada.jenis,
      isAlatBerat: armada.isAlatBerat,
      titikId: armada.titikId,
      jumlah: jumlah,
      satuan: _satuan,
      catatan: _catatanCtrl.text.trim().isEmpty
          ? null
          : _catatanCtrl.text.trim(),
      odoPerTrip: double.tryParse(_odoCtrl.text.trim()),
      createdAt: existing?.createdAt ?? now,
      // Edit = mulai fresh dari draft (idempotency dichecksum ulang).
      status: RitaseRecordStatus.draft,
      clientUuid: _uuid.v4(),
      idempotencyKey: _uuid.v4(),
    );

    AnalyticsService.ritaseRecordAdd();
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, color: Colors.transparent),
                const Spacer(),
                Text(
                  existing == null
                      ? 'Tambah Muatan #${widget.nextIndex}'
                      : 'Edit Muatan #${existing.index}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),

            DropdownButtonFormField<ArmadaSaya>(
              initialValue: _armada,
              decoration: const InputDecoration(
                labelText: 'Kendaraan',
                border: OutlineInputBorder(),
              ),
              items: widget.armadaList
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text('${a.platNomor} — ${a.jenis ?? 'N/A'}'),
                    ),
                  )
                  .toList(),
              onChanged: _isSingleUnit
                  ? null
                  : (v) {
                      setState(() {
                        _armada = v;
                        if (v != null && _odoCtrl.text.isEmpty) {
                          final odo = v.odoTerkini;
                          if (odo != null) {
                            _odoCtrl.text = odo.toString();
                          }
                        }
                      });
                    },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _jumlahCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _satuan,
                    decoration: const InputDecoration(
                      labelText: 'Satuan',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _satuanOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _satuan = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _catatanCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _odoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'ODO per trip (opsional)',
                border: OutlineInputBorder(),
                helperText: 'Dikirim sebagai odo_per_trip ke server bila diisi',
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 48,
              child: BouncingButton(
                onPressed: _save,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(
                    existing == null
                        ? 'Simpan Muatan #${widget.nextIndex}'
                        : 'Update Muatan #${existing.index}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Review sheet (detail muatan terstruktur)
// ---------------------------------------------------------------------------

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({required this.record});

  final RitaseRecord record;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (record.status) {
      RitaseRecordStatus.synced => context.colors.success,
      RitaseRecordStatus.queued => context.colors.warning,
      RitaseRecordStatus.failed => context.colors.error,
      RitaseRecordStatus.draft => Colors.blueGrey,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detail Muatan #${record.index}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    record.status.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  _ReviewRow(
                    label: 'Kendaraan',
                    value:
                        '${record.armadaPlat ?? '-'}${record.armadaJenis != null ? ' • ${_labelJenis(record.armadaJenis)}' : ''}',
                  ),
                  const Divider(height: 12),
                  _ReviewRow(
                    label: 'Jumlah Muatan',
                    value: '${record.jumlah} ${record.satuan}',
                  ),
                  const Divider(height: 12),
                  _ReviewRow(
                    label: 'Satuan Sistem',
                    value: record.satuanVolume,
                  ),
                  if (record.odoPerTrip != null) ...[
                    const Divider(height: 12),
                    _ReviewRow(
                      label: 'ODO Per Trip',
                      value: '${fmtOdo(record.odoPerTrip!)} km',
                    ),
                  ],
                  if (record.catatan != null &&
                      record.catatan!.trim().isNotEmpty) ...[
                    const Divider(height: 12),
                    _ReviewRow(label: 'Catatan', value: record.catatan!.trim()),
                  ],
                  const Divider(height: 12),
                  _ReviewRow(
                    label: 'Waktu Input',
                    value:
                        '${fmtTanggal(record.createdAt.toIso8601String())} ${record.createdAt.hour.toString().padLeft(2, '0')}:${record.createdAt.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
            if (record.errorMessage != null &&
                record.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.colors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: context.colors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        record.errorMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
