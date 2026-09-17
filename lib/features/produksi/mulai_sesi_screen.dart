import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics_service.dart';
import '../../core/api_client.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../presensi/models/titik.dart';
import '../presensi/presensi_providers.dart';
import '../titik/titik_selector.dart';
import 'models/master.dart';
import 'produksi_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Halaman "Mulai Sesi" — wizard bertahap (Phase 13):
/// 1. Mesin (wajib)
/// 2. Produk (wajib, auto-prefill bila hanya satu produk tersedia atau
///    mesin punya produk_default)
/// 3. Titik (opsional, default "Otomatis mengikuti titik mesin")
/// 4. Catatan (opsional)
/// 5. Review & Mulai Sesi
///
/// Validasi inline muncul bila user menekan "Lanjut" dengan kolom wajib
/// yang belum diisi. Tombol "Kembali" mengembalikan ke langkah sebelumnya
/// tanpa kehilangan state.
class MulaiSesiScreen extends ConsumerStatefulWidget {
  const MulaiSesiScreen({super.key});

  @override
  ConsumerState<MulaiSesiScreen> createState() => _MulaiSesiScreenState();
}

class _MulaiSesiScreenState extends ConsumerState<MulaiSesiScreen> {
  int _currentStep = 0;
  MesinMaster? _mesin;
  ProdukMaster? _produk;
  Titik? _titik;
  final _catatanCtrl = TextEditingController();

  String? _errorMesin;
  String? _errorProduk;

  @override
  void dispose() {
    _catatanCtrl.dispose();
    super.dispose();
  }

  // Langkah efektif tidak berubah: Mesin(0) → Produk(1) → Titik(2) →
  // Catatan(3) → Review(4). Step label tetap "Langkah X dari 5".
  static const int _totalSteps = 5;
  static const List<String> _stepLabels = [
    'Mesin',
    'Produk',
    'Titik',
    'Catatan',
    'Review & Mulai',
  ];

  bool get _isLastStep => _currentStep == _totalSteps - 1;

  bool _validateCurrentStep(List<ProdukMaster> produkList) {
    switch (_currentStep) {
      case 0:
        if (_mesin == null) {
          setState(() => _errorMesin = 'Pilih mesin terlebih dahulu.');
          return false;
        }
        setState(() => _errorMesin = null);
        return true;
      case 1:
        if (_produk == null) {
          setState(() => _errorProduk = 'Pilih produk terlebih dahulu.');
          return false;
        }
        setState(() => _errorProduk = null);
        return true;
      default:
        return true;
    }
  }

  void _nextStep(List<ProdukMaster> produkList) {
    if (!_validateCurrentStep(produkList)) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _onMesinChanged(MesinMaster? mesin, List<ProdukMaster> produkList) {
    setState(() {
      _mesin = mesin;
      _errorMesin = null;
      // Prefill produk default milik mesin bila ada di daftar produk.
      ProdukMaster? prefill;
      if (mesin?.produkDefaultId != null) {
        for (final p in produkList) {
          if (p.id == mesin!.produkDefaultId) {
            prefill = p;
            break;
          }
        }
      }
      // Jika hanya satu produk tersedia, paksa prefill.
      if (prefill == null && produkList.length == 1) {
        prefill = produkList.single;
      }
      if (prefill != null) _produk = prefill;
    });
  }

  Future<void> _submit() async {
    if (_mesin == null || _produk == null) return;

    final result = await ref
        .read(produksiSubmitProvider.notifier)
        .mulai(
          mesinId: _mesin!.id,
          produkId: _produk!.id,
          titikId: _titik?.id,
          catatan: _catatanCtrl.text.trim(),
        );

    AnalyticsService.produksiSesiMulai();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.delivered || result.queued) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.delivered
                ? 'Sesi produksi dimulai.'
                : kCopyQueued,
          ),
        ),
      );
    } else if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(produksiSubmitProvider).busy;
    final mesinAsync = ref.watch(mesinProvider);
    final produkAsync = ref.watch(produkProvider);
    final titikAsync = ref.watch(titikAktifProvider);
    final produkList = produkAsync.value ?? const <ProdukMaster>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLastStep
              ? 'Review & Mulai Sesi'
              : 'Langkah ${_currentStep + 1} dari $_totalSteps',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: Column(
        children: [
          // Step progress indicator.
          _StepProgressIndicator(
            current: _currentStep,
            total: _totalSteps,
            labels: _stepLabels,
            hasError: (_currentStep == 0 && _errorMesin != null) ||
                (_currentStep == 1 && _errorProduk != null),
          ),
          // Step content.
          Expanded(
            child: mesinAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonDetailView(),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e is ApiException ? e.message : 'Gagal memuat master data.',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(mesinProvider),
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
              data: (mesinList) {
                // Auto-select mesin jika hanya ada 1 dan belum dipilih.
                if (mesinList.length == 1 && _mesin == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _onMesinChanged(mesinList.single, produkList);
                  });
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildStepContent(mesinList, produkList, titikAsync),
                  ],
                );
              },
            ),
          ),
          // Navigation buttons.
          _buildBottomNav(produkList, busy),
        ],
      ),
    );
  }

  Widget _buildStepContent(
    List<MesinMaster> mesinList,
    List<ProdukMaster> produkList,
    AsyncValue<List<Titik>> titikAsync,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildMesinStep(mesinList, produkList);
      case 1:
        return _buildProdukStep(produkList);
      case 2:
        return _buildTitikStep(titikAsync);
      case 3:
        return _buildCatatanStep();
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMesinStep(List<MesinMaster> mesinList, List<ProdukMaster> produkList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Mesin',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Pilih mesin yang akan digunakan sesi ini.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<MesinMaster>(
          initialValue: _mesin,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Mesin *',
            border: const OutlineInputBorder(),
            errorText: _errorMesin,
          ),
          items: [
            for (final m in mesinList)
              DropdownMenuItem(value: m, child: Text(m.nama)),
          ],
          onChanged: (v) => _onMesinChanged(v, produkList),
        ),
        if (_mesin != null) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.engineering),
              title: Text(_mesin!.nama),
              subtitle: Text([
                if (_mesin!.titikNama != null) 'Titik: ${_mesin!.titikNama}',
                if (_mesin!.produkDefaultNama != null)
                  'Produk default: ${_mesin!.produkDefaultNama}',
                if (_mesin!.kapasitas != null)
                  'Kapasitas: ${_mesin!.kapasitas} unit',
              ].join(' • ')),
              dense: true,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_errorMesin != null)
          Text(
            _errorMesin!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _buildProdukStep(List<ProdukMaster> produkList) {
    final isPrefilled = _produk != null &&
        _mesin?.produkDefaultId == _produk!.id;
    final singleProduct = produkList.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Produk',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          singleProduct
              ? 'Hanya satu produk tersedia — diisi otomatis.'
              : isPrefilled
                  ? 'Produk diisi otomatis dari mesin. Anda dapat mengubahnya.'
                  : 'Pilih jenis produk yang akan diproduksi.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<ProdukMaster>(
          key: ValueKey(_produk?.id ?? 'produk-none'),
          initialValue: _produk,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Produk *',
            border: const OutlineInputBorder(),
            errorText: _errorProduk,
            helperText: isPrefilled ? 'Diisi otomatis dari mesin' : null,
          ),
          items: [
            for (final p in produkList)
              DropdownMenuItem(value: p, child: Text(p.nama)),
          ],
          onChanged: (v) => setState(() {
            _produk = v;
            _errorProduk = null;
          }),
        ),
        if (_errorProduk != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              _errorProduk!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTitikStep(AsyncValue<List<Titik>> titikAsync) {
    final titikList = titikAsync.value ?? const <Titik>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Titik Kerja',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Opsional — kosongkan untuk otomatis mengikuti titik mesin.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        if (titikList.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: context.colors.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tidak ada titik tersedia — akan menggunakan titik default mesin.',
                      style: TextStyle(color: context.colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          TitikSelector(
            titikList: titikList,
            selectedTitik: _titik,
            mapHeight: 220,
            onChanged: (t) => setState(() => _titik = t),
            listBuilder: (context, _) => DropdownButtonFormField<Titik?>(
              initialValue: _titik,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Titik Kerja (opsional)',
                border: OutlineInputBorder(),
                helperText: 'Kosongkan untuk otomatis mengikuti titik mesin',
              ),
              items: [
                const DropdownMenuItem<Titik?>(
                  value: null,
                  child: Text('Otomatis (ikuti titik mesin)'),
                ),
                for (final t in titikList)
                  DropdownMenuItem<Titik?>(value: t, child: Text(t.nama)),
              ],
              onChanged: (v) => setState(() => _titik = v),
            ),
          ),
      ],
    );
  }

  Widget _buildCatatanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catatan',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Opsional — tambahkan catatan untuk sesi ini.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _catatanCtrl,
          maxLines: 4,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & Mulai Sesi',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Periksa data berikut sebelum memulai sesi.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        _ReviewItem(
          label: 'Mesin',
          value: _mesin?.nama ?? '-',
          icon: Icons.engineering,
          isRequired: true,
        ),
        _ReviewItem(
          label: 'Produk',
          value: _produk?.nama ?? '-',
          icon: Icons.inventory_2_outlined,
          isRequired: true,
        ),
        _ReviewItem(
          label: 'Titik Kerja',
          value: _titik?.nama ?? 'Otomatis (ikuti titik mesin)',
          icon: Icons.location_on_outlined,
          isRequired: false,
        ),
        if (_mesin?.titikNama != null && _titik == null)
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Text(
              'Menggunakan: ${_mesin!.titikNama}',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: context.colors.textTertiary,
              ),
            ),
          ),
        _ReviewItem(
          label: 'Catatan',
          value: _catatanCtrl.text.trim().isEmpty
              ? '(tidak ada)'
              : _catatanCtrl.text.trim(),
          icon: Icons.notes,
          isRequired: false,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBottomNav(List<ProdukMaster> produkList, bool busy) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _prevStep,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Kembali'),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : _isLastStep
                        ? _submit
                        : () => _nextStep(produkList),
                icon: Icon(
                  _isLastStep ? Icons.play_arrow : Icons.arrow_forward,
                  size: 18,
                ),
                label: Text(
                  busy
                      ? 'Memulai...'
                      : _isLastStep
                          ? 'Mulai Sesi'
                          : 'Lanjut',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepProgressIndicator extends StatelessWidget {
  const _StepProgressIndicator({
    required this.current,
    required this.total,
    required this.labels,
    required this.hasError,
  });

  final int current;
  final int total;
  final List<String> labels;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${labels[current]} — Langkah ${current + 1} dari $total',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasError ? theme.colorScheme.error : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(total, (i) {
              final isCompleted = i < current;
              final color = i == current
                  ? (hasError ? theme.colorScheme.error : theme.colorScheme.primary)
                  : isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(total, (i) {
              final isActive = i == current;
              final isCompleted = i < current;
              final dotColor = isCompleted
                  ? theme.colorScheme.primary
                  : isActive
                      ? (hasError ? theme.colorScheme.error : theme.colorScheme.primary)
                      : theme.colorScheme.outlineVariant;
              return Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.isRequired,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: context.colors.primary.withValues(alpha: 0.1),
            child: Icon(icon, size: 18, color: context.colors.primary),
          ),
          title: Text(label),
          subtitle: Text(
            '$value${isRequired ? ' *' : ' (opsional)'}',
            style: TextStyle(
              color: context.colors.textSecondary,
            ),
          ),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        ),
      ),
    );
  }
}