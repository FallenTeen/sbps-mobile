import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'armada_providers.dart';
import 'models/armada.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Checklist harian armada: menampilkan status tiap kendaraan hari ini dan
/// form pencatatan/ubah kondisi kendaraan.
class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  Future<void> _openForm(ArmadaChecklist item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChecklistForm(
        item: item,
        onSave: ({
          required bool kondisiBaik,
          required String masalah,
          double? solarLiter,
          double? odoKm,
          double? jamOperasional,
        }) async {
          await ref.read(armadaRepositoryProvider).submitChecklist(
                armadaId: item.armadaId,
                kondisiBaik: kondisiBaik,
                itemBermasalah: masalah,
                solarLiter: solarLiter,
                odoKm: odoKm,
                jamOperasional: jamOperasional,
              );
          ref.invalidate(checklistHariIniProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checklist = ref.watch(checklistHariIniProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checklist Harian'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(checklistHariIniProvider),
        child: switch (checklist) {
          AsyncData(value: final items) => items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 160),
                  Icon(Icons.checklist_rtl, size: 44),
                  SizedBox(height: 12),
                  Text('Belum ada armada untuk dicatat.',
                      textAlign: TextAlign.center),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ChecklistCard(
                    item: items[i],
                    onTap: () => _openForm(items[i]),
                  ),
                ),
          AsyncError(:final error) => ListView(children: [
              const SizedBox(height: 120),
              Text('$error', textAlign: TextAlign.center),
            ]),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.item, required this.onTap});

  final ArmadaChecklist item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = item.sudahIsi;
    return Card(
      child: ListTile(
        leading: Icon(
          filled
              ? Icons.check_circle
              : Icons.radio_button_unchecked,
          color: filled ? Colors.green : scheme.outline,
        ),
        title: Text(item.platNomor,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          filled
              ? (item.kondisiBaik == true
                  ? 'Kondisi baik${_masalahSuffix(item.itemBermasalah)}'
                  : 'Ada masalah${_masalahSuffix(item.itemBermasalah)}')
              : 'Belum dicatat hari ini',
        ),
        trailing: const Icon(Icons.edit_outlined),
        onTap: onTap,
      ),
    );
  }

  String _masalahSuffix(String? masalah) =>
      (masalah == null || masalah.isEmpty) ? '' : ' — $masalah';
}

class _ChecklistForm extends ConsumerStatefulWidget {
  const _ChecklistForm({required this.item, required this.onSave});

  final ArmadaChecklist item;
  final Future<void> Function({
    required bool kondisiBaik,
    required String masalah,
    double? solarLiter,
    double? odoKm,
    double? jamOperasional,
  }) onSave;

  @override
  ConsumerState<_ChecklistForm> createState() => _ChecklistFormState();
}

class _ChecklistFormState extends ConsumerState<_ChecklistForm> {
  bool _kondisiBaik = true;
  final _masalah = TextEditingController();
  final _solarCtrl = TextEditingController();
  final _odoCtrl = TextEditingController();
  final _jamCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _kondisiBaik = widget.item.kondisiBaik ?? true;
    _masalah.text = widget.item.itemBermasalah ?? '';
    if (widget.item.solarLiter != null) {
      _solarCtrl.text = widget.item.solarLiter.toString();
    }
    if (widget.item.odoKm != null) {
      _odoCtrl.text = widget.item.odoKm.toString();
    }
    if (widget.item.jamOperasional != null) {
      _jamCtrl.text = widget.item.jamOperasional.toString();
    }
  }

  @override
  void dispose() {
    _masalah.dispose();
    _solarCtrl.dispose();
    _odoCtrl.dispose();
    _jamCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.onSave(
        kondisiBaik: _kondisiBaik,
        masalah: _masalah.text.trim(),
        solarLiter: double.tryParse(_solarCtrl.text),
        odoKm: double.tryParse(_odoCtrl.text),
        jamOperasional: double.tryParse(_jamCtrl.text),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.item.platNomor,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Checklist hari ini',
                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kondisi kendaraan baik'),
              subtitle: const Text('Matikan bila ada masalah'),
              value: _kondisiBaik,
              onChanged: (v) => setState(() => _kondisiBaik = v),
            ),
            if (!_kondisiBaik)
              TextField(
                controller: _masalah,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Item yang bermasalah',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            // Section 21: Solar, ODO, Jam Operasional.
            Text('Data Operasional',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _solarCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Solar (liter)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _odoCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'ODO (km)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _jamCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jam Operasional',
                border: OutlineInputBorder(),
                helperText: 'Untuk alat stasioner',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Menyimpan...' : 'Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
