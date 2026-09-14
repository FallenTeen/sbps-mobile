import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'armada_providers.dart';
import 'models/armada.dart';

/// Data model untuk satu record ritase.
class RitaseRecord {
  RitaseRecord({
    required this.index,
    this.armada,
    this.jumlah,
    this.satuan = 'rit',
    this.catatan = '',
    this.odoPerTrip,
  });

  final int index;
  ArmadaSaya? armada;
  int? jumlah;
  String satuan;
  String catatan;
  double? odoPerTrip;

  bool get isComplete => armada != null && jumlah != null && jumlah! > 0;

  Map<String, dynamic> toPayload() => {
    'armada_id': armada?.id,
    'jumlah': jumlah,
    'satuan': satuan,
    'catatan': catatan.isEmpty ? null : catatan,
    'odo_per_trip': odoPerTrip,
  };
}

/// Input muatan ringkas untuk Driver (Section 21.4):
/// Driver mencatat jumlah muatan dan satuan dari lapangan.
/// Mendukung multi-record dengan indexing.
class RitaseInputScreen extends ConsumerStatefulWidget {
  const RitaseInputScreen({super.key});

  @override
  ConsumerState<RitaseInputScreen> createState() => _RitaseInputScreenState();
}

class _RitaseInputScreenState extends ConsumerState<RitaseInputScreen> {
  final List<RitaseRecord> _records = [];
  int _currentRecordIndex = -1; // -1 = mode tambah baru

  final _jumlahRitCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();
  final _odoPerTripCtrl = TextEditingController();
  ArmadaSaya? _selectedArmada;
  String _selectedSatuan = 'rit';
  bool _isLoading = false;

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

  @override
  void dispose() {
    _jumlahRitCtrl.dispose();
    _catatanCtrl.dispose();
    _odoPerTripCtrl.dispose();
    super.dispose();
  }

  int get _nextIndex => _records.isEmpty ? 1 : _records.last.index + 1;

  void _startNewRecord() {
    setState(() {
      _currentRecordIndex = -1;
      _selectedArmada = null;
      _jumlahRitCtrl.clear();
      _catatanCtrl.clear();
      _odoPerTripCtrl.clear();
      _selectedSatuan = 'rit';
    });
  }

  void _editRecord(int recordIndex) {
    final record = _records.firstWhere((r) => r.index == recordIndex);
    setState(() {
      _currentRecordIndex = recordIndex;
      _selectedArmada = record.armada;
      _jumlahRitCtrl.text = record.jumlah?.toString() ?? '';
      _catatanCtrl.text = record.catatan;
      _selectedSatuan = record.satuan;
      _odoPerTripCtrl.text = record.odoPerTrip?.toString() ?? '';
    });
  }

  void _saveCurrentRecord() {
    if (_selectedArmada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kendaraan terlebih dahulu')),
      );
      return;
    }

    final jumlah = int.tryParse(_jumlahRitCtrl.text.trim());
    if (jumlah == null || jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah muatan harus angka positif')),
      );
      return;
    }

    HapticFeedback.lightImpact();
    final newRecord = RitaseRecord(
      index: _currentRecordIndex == -1 ? _nextIndex : _currentRecordIndex,
      armada: _selectedArmada,
      jumlah: jumlah,
      satuan: _selectedSatuan,
      catatan: _catatanCtrl.text.trim(),
      odoPerTrip: double.tryParse(_odoPerTripCtrl.text),
    );

    setState(() {
      if (_currentRecordIndex == -1) {
        _records.add(newRecord);
      } else {
        final idx = _records.indexWhere((r) => r.index == _currentRecordIndex);
        if (idx >= 0) _records[idx] = newRecord;
      }
    });

    AnalyticsService.ritaseRecordAdd();

    _startNewRecord();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Muatan #${newRecord.index} tersimpan di daftar')),
    );
  }

  void _deleteRecord(int recordIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      _records.removeWhere((r) => r.index == recordIndex);
      if (_currentRecordIndex == recordIndex) _startNewRecord();
    });
  }

  Future<void> _submitAll() async {
    final incomplete = _records.where((r) => !r.isComplete).toList();
    if (incomplete.isNotEmpty) {
      final nums = incomplete.map((r) => '#${r.index}').join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Muatan $nums belum lengkap — periksa kembali')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      var delivered = true;
      for (final record in _records) {
        final satuanVolume = switch (record.satuan) {
          'rit' => 'ritase',
          'ton' => 'tonase',
          'm³' => 'm3',
          _ => 'ritase',
        };
        final sent = await ref
            .read(armadaRepositoryProvider)
            .submitRitase(
              armadaId: record.armada!.id,
              jumlahRit: record.jumlah!,
              satuanVolume: satuanVolume,
              catatan: record.catatan,
            );
        delivered = delivered && sent;
      }

      if (!mounted) return;
      HapticFeedback.lightImpact();
      AnalyticsService.ritaseSubmitAll(_records.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered
                ? '${_records.length} muatan berhasil dikirim'
                : '${_records.length} muatan tersimpan dan akan dikirim saat online',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal mengirim muatan.\nPeriksa koneksi lalu coba lagi.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armadaAsync = ref.watch(armadaSayaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Muatan'),
        actions:  [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (_, __) => AppEmptyState(
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

          return Column(
            children: [
              // === DAFTAR RECORD ===
              if (_records.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: context.colors.primary.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Icon(
                        Icons.list_alt,
                        size: 18,
                        color: context.colors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${_records.length} Record Tersimpan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _startNewRecord,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Baru'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: _records.length,
                    itemBuilder: (context, idx) {
                      final record = _records[idx];
                      final isActive = _currentRecordIndex == record.index;
                      return Container(
                        width: 150,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? context.colors.primary.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? context.colors.primary
                                : Colors.grey.shade300,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _editRecord(record.index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: record.isComplete
                                          ? Colors.green.withValues(alpha: 0.12)
                                          : Colors.orange.withValues(
                                              alpha: 0.12,
                                            ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${record.index}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: record.isComplete
                                            ? Colors.green.shade700
                                            : Colors.orange.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (record.isComplete)
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 14,
                                    color: Colors.green,
                                  )
                                else
                                  Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.orange.shade600,
                                  ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    iconSize: 16,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Hapus muatan ini',
                                    onPressed: () =>
                                        _confirmDelete(record.index),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _editRecord(record.index),
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    record.armada?.platNomor ?? '-',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '${record.jumlah ?? '-'} ${record.satuan}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.colors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
              ],

              // === FORM INPUT ===
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header record
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note,
                              color: context.colors.primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _currentRecordIndex == -1
                                  ? 'Record Baru #$_nextIndex'
                                  : 'Edit Record #$_currentRecordIndex',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pilih kendaraan
                      Text(
                        'Kendaraan',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ArmadaSaya>(
                        decoration: const InputDecoration(
                          labelText: 'Pilih Kendaraan',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: _selectedArmada,
                        items: armadaList.map((a) {
                          return DropdownMenuItem(
                            value: a,
                            child: Text('${a.platNomor} — ${a.jenis ?? 'N/A'}'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedArmada = v;
                            if (v != null && _odoPerTripCtrl.text.isEmpty) {
                              final odo = v.odoTerkini;
                              if (odo != null) {
                                _odoPerTripCtrl.text = odo.toString();
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Jumlah rit
                      Text(
                        'Jumlah',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _jumlahRitCtrl,
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
                              initialValue: _selectedSatuan,
                              decoration: const InputDecoration(
                                labelText: 'Satuan',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: _satuanOptions.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(s),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null)
                                  setState(() => _selectedSatuan = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Catatan (opsional)
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
                        controller: _odoPerTripCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'KM / Odometer (opsional)',
                          border: OutlineInputBorder(),
                          helperText:
                              'Angka pada odometer (penghitung km) kendaraan — opsional',
                        ),
                      ),
                      const SizedBox(height: 20),

                      SizedBox(
                        height: 48,
                        child: BouncingButton(
                          onPressed: _saveCurrentRecord,
                          child: FilledButton.icon(
                            onPressed: _saveCurrentRecord,
                            icon: const Icon(Icons.save, size: 18),
                            label: Text(
                              _currentRecordIndex == -1
                                  ? 'Simpan Muatan #$_nextIndex'
                                  : 'Update Muatan #$_currentRecordIndex',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_records.isNotEmpty)
                Container(
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
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: BouncingButton(
                      onPressed: _isLoading ? null : _submitAll,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _submitAll,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, size: 18),
                        label: Text(
                          _isLoading
                              ? 'Mengirim...'
                              : 'Kirim Semua Muatan (${_records.length})',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(int recordIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Record #$recordIndex?'),
        content: const Text('Data record ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteRecord(recordIndex);
            },
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
