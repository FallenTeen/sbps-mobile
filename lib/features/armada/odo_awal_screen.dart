import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'armada_providers.dart';
import 'models/armada.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Input ODO awal proyek dengan alur step-based:
/// Step 1: Pilih konteks (hari ini / angkutan keberapa)
/// Step 2: Input nilai ODO
class OdoAwalScreen extends ConsumerStatefulWidget {
  const OdoAwalScreen({super.key});

  @override
  ConsumerState<OdoAwalScreen> createState() => _OdoAwalScreenState();
}

class _OdoAwalScreenState extends ConsumerState<OdoAwalScreen> {
  int _currentStep = 0;
  ArmadaSaya? _selectedArmada;
  _TripContext? _selectedContext;
  final _odoAwalController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _odoAwalController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _onArmadaChanged(ArmadaSaya? armada) {
    setState(() => _selectedArmada = armada);
  }

  void _onContextChanged(_TripContext? context) {
    setState(() => _selectedContext = context);
  }

  Future<void> _submit() async {
    if (_selectedArmada == null || _selectedContext == null) return;
    if (_odoAwalController.text.trim().isEmpty) return;

    final odoValue = double.tryParse(_odoAwalController.text.trim());
    if (odoValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Format angka ODO tidak valid')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final delivered = await ref.read(armadaRepositoryProvider).submitOdoAwalProyek(
            armadaId: _selectedArmada!.id,
            titikId: _selectedArmada!.titikId ?? '',
            odoAwal: odoValue,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(delivered
              ? 'Berhasil menyimpan ODO awal'
              : 'Tersimpan. Menunggu sinkronisasi saat online.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan yang tidak terduga')),
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
        title: const Text('ODO Awal Proyek'),
        actions: const [PortalSwitchButton()],
      ),
      body: armadaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Gagal memuat daftar armada: $error')),
        data: (armadaList) {
          if (armadaList.isEmpty) {
            return const AppEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'Tidak ada armada',
              subtitle: 'Anda belum memiliki armada yang ditugaskan.',
            );
          }

          return Column(
            children: [
              _StepIndicator(currentStep: _currentStep),
              Expanded(
                child: _currentStep == 0
                    ? _StepContextSelection(
                        armadaList: armadaList,
                        selectedArmada: _selectedArmada,
                        selectedContext: _selectedContext,
                        onArmadaChanged: _onArmadaChanged,
                        onContextChanged: _onContextChanged,
                        onNext:
                            _selectedArmada != null && _selectedContext != null
                                ? _nextStep
                                : null,
                      )
                    : _StepOdoInput(
                        armada: _selectedArmada!,
                        context_: _selectedContext!,
                        odoController: _odoAwalController,
                        isLoading: _isLoading,
                        onBack: _prevStep,
                        onSubmit: _submit,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Step indicator dots.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ['Pilih Kendaraan', 'Input ODO'];
    final currentLabel = currentStep < labels.length ? labels[currentStep] : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Text(
            'Langkah ${currentStep + 1} dari ${labels.length} — $currentLabel',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StepDot(
                label: labels[0],
                isActive: currentStep >= 0,
                isCurrent: currentStep == 0,
              ),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: currentStep >= 1
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              _StepDot(
                label: labels[1],
                isActive: currentStep >= 1,
                isCurrent: currentStep == 1,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.isActive,
    required this.isCurrent,
  });

  final String label;
  final bool isActive;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? theme.colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: color,
              width: isCurrent ? 3 : 2,
            ),
          ),
          child: Center(
            child: isActive
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${_labelToIndex(label)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }

  int _labelToIndex(String label) => label == 'Konteks' ? 1 : 2;
}

/// Step 1: Pilih konteks ritase (armada + hari/angkutan).
class _StepContextSelection extends StatelessWidget {
  const _StepContextSelection({
    required this.armadaList,
    required this.selectedArmada,
    required this.selectedContext,
    required this.onArmadaChanged,
    required this.onContextChanged,
    required this.onNext,
  });

  final List<ArmadaSaya> armadaList;
  final ArmadaSaya? selectedArmada;
  final _TripContext? selectedContext;
  final ValueChanged<ArmadaSaya?> onArmadaChanged;
  final ValueChanged<_TripContext?> onContextChanged;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayStr =
        '${now.day}/${now.month}/${now.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Pilih Kendaraan',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ArmadaSaya>(
            decoration: const InputDecoration(
              labelText: 'Kendaraan',
              border: OutlineInputBorder(),
            ),
            initialValue: selectedArmada,
            items: armadaList.map((a) {
              return DropdownMenuItem(
                value: a,
                child: Text('${a.platNomor} - ${a.jenis ?? 'N/A'}'),
              );
            }).toList(),
            onChanged: onArmadaChanged,
            validator: (v) => v == null ? 'Wajib dipilih' : null,
          ),
          if (selectedArmada?.titikNama != null) ...[
            const SizedBox(height: 8),
            Text(
              'Titik: ${selectedArmada!.titikNama}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary),
            ),
          ],
          const SizedBox(height: 24),
          Text('Pilih Konteks Ritase',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'Pilih hari atau angkutan keberapa hari ini untuk input ODO.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _ContextOption(
            icon: Icons.today,
            title: 'Hari Ini',
            subtitle: '$todayStr — Angkutan ke-1',
            isSelected: selectedContext?.type == _ContextType.todayFirst,
            onTap: () => onContextChanged(_TripContext(
              type: _ContextType.todayFirst,
              label: 'Hari Ini — Angkutan ke-1',
            )),
          ),
          const SizedBox(height: 8),
          _ContextOption(
            icon: Icons.today,
            title: 'Hari Ini — Angkutan ke-2',
            subtitle: '$todayStr — Angkutan ke-2',
            isSelected: selectedContext?.type == _ContextType.todaySecond,
            onTap: () => onContextChanged(_TripContext(
              type: _ContextType.todaySecond,
              label: 'Hari Ini — Angkutan ke-2',
            )),
          ),
          const SizedBox(height: 8),
          _ContextOption(
            icon: Icons.today,
            title: 'Hari Ini — Angkutan ke-3',
            subtitle: '$todayStr — Angkutan ke-3',
            isSelected: selectedContext?.type == _ContextType.todayThird,
            onTap: () => onContextChanged(_TripContext(
              type: _ContextType.todayThird,
              label: 'Hari Ini — Angkutan ke-3',
            )),
          ),
          const SizedBox(height: 8),
          _ContextOption(
            icon: Icons.calendar_today,
            title: 'Hari Lainnya',
            subtitle: 'Pilih tanggal sendiri',
            isSelected: selectedContext?.type == _ContextType.customDate,
            onTap: () => onContextChanged(_TripContext(
              type: _ContextType.customDate,
              label: 'Tanggal custom',
            )),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onNext,
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }
}

/// Step 2: Input nilai ODO.
class _StepOdoInput extends StatelessWidget {
  const _StepOdoInput({
    required this.armada,
    required this.context_,
    required this.odoController,
    required this.isLoading,
    required this.onBack,
    required this.onSubmit,
  });

  final ArmadaSaya armada;
  final _TripContext context_;
  final TextEditingController odoController;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_shipping,
                          color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          armada.platNomor,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context_.label,
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (armada.titikNama != null)
                    Text(
                      'Titik: ${armada.titikNama}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Masukkan ODO Awal',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            'ODO (odometer) saat ini dalam satuan KM.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: odoController,
            decoration: const InputDecoration(
              labelText: 'ODO Awal (KM)',
              border: OutlineInputBorder(),
              suffixText: 'KM',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'ODO awal wajib diisi';
              }
              if (double.tryParse(value) == null) {
                return 'Format angka tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              OutlinedButton(
                onPressed: isLoading ? null : onBack,
                child: const Text('Kembali'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isLoading ? null : onSubmit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan ODO Awal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContextOption extends StatelessWidget {
  const _ContextOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: ListTile(
        leading: Icon(icon,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : const Icon(Icons.radio_button_unchecked),
        onTap: onTap,
      ),
    );
  }
}

enum _ContextType {
  todayFirst,
  todaySecond,
  todayThird,
  customDate,
}

class _TripContext {
  const _TripContext({required this.type, required this.label});

  final _ContextType type;
  final String label;
}
