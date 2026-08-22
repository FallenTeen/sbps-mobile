import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../formulir/formulir_screen.dart';
import '../home/home_shell.dart';
import 'models/titik.dart';
import 'presensi_hari_ini_card.dart';
import 'presensi_providers.dart';
import 'riwayat_screen.dart';

/// Fase A1.3 — daftar titik kerja aktif dengan jarak GPS ke tiap titik,
/// penanda titik terdekat, dan pemilihan titik untuk alur check-in (A1.4).
class TitikKerjaScreen extends ConsumerStatefulWidget {
  const TitikKerjaScreen({super.key});

  @override
  ConsumerState<TitikKerjaScreen> createState() => _TitikKerjaScreenState();
}

class _TitikKerjaScreenState extends ConsumerState<TitikKerjaScreen> {
  bool _loadingPosition = true;
  String? _locationProblem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPosition());
  }

  Future<void> _loadPosition() async {
    final location = ref.read(locationServiceProvider);
    setState(() {
      _loadingPosition = true;
      _locationProblem = null;
    });

    final serviceOn = await location.isServiceEnabled();
    if (!serviceOn) {
      setState(() {
        _loadingPosition = false;
        _locationProblem =
            'Lokasi (GPS) sedang mati. Aktifkan untuk melihat jarak ke titik.';
      });
      return;
    }

    final granted = await location.ensurePermission();
    if (!granted) {
      setState(() {
        _loadingPosition = false;
        _locationProblem =
            'Izin lokasi belum diberikan. Presensi butuh lokasi Anda.';
      });
      return;
    }

    final position = await location.getCurrentPosition();
    if (!mounted) return;
    setState(() => _loadingPosition = false);
    if (position != null) {
      ref.read(currentPositionProvider.notifier).update(position);
    } else {
      setState(() {
        _locationProblem =
            'Posisi GPS belum didapat. Coba lagi dari area terbuka.';
      });
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _refreshAll() async {
    ref.invalidate(titikAktifProvider);
    ref.invalidate(assignmentsProvider);
    await _loadPosition();
  }

  void _selectTitik(Titik titik) {
    ref.read(selectedTitikProvider.notifier).select(titik);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Titik ${titik.nama} dipilih.')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.value;
    final titikAsync = ref.watch(titikAktifProvider);
    final assignmentsAsync = ref.watch(assignmentsProvider);
    final position = ref.watch(currentPositionProvider);
    final selectedId = ref.watch(selectedTitikProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const HomeTitle(),
        actions: [
          IconButton(
            tooltip: 'Riwayat presensi',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RiwayatScreen(),
              ),
            ),
          ),
          const _PendingBadgeAction(),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (user != null && !user.hasKaryawan) ...[
              MaterialBanner(
                backgroundColor:
                    Theme.of(context).colorScheme.errorContainer,
                contentTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                content: const Text(
                  'Akun Anda belum terhubung ke data karyawan, hubungi admin.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('Tutup'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else if (assignmentsAsync.value != null &&
                assignmentsAsync.value!.isEmpty &&
                assignmentsAsync.hasValue) ...[
              MaterialBanner(
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                content: const Text('Belum ada penugasan, hubungi admin.'),
                actions: [
                  TextButton(
                    onPressed: () {},
                    child: const Text('Tutup'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const PresensiHariIniCard(),
            const _FormulirEntryPoint(),
            _LocationCard(
              loading: _loadingPosition,
              problem: _locationProblem,
              onOpenSettings: () =>
                  ref.read(locationServiceProvider).openSettings(),
              onRetry: _loadPosition,
            ),
            const SizedBox(height: 16),

            Text('Titik Kerja Aktif',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            titikAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Card(
                child: ListTile(
                  leading: Icon(Icons.error_outline,
                      color: Theme.of(context).colorScheme.error),
                  title: const Text('Gagal memuat titik kerja'),
                  subtitle: Text(error.toString()),
                  trailing: TextButton(
                    onPressed: () => ref.invalidate(titikAktifProvider),
                    child: const Text('Coba lagi'),
                  ),
                ),
              ),
              data: (titikList) {
                if (titikList.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Belum ada titik kerja aktif.'),
                      ),
                    ),
                  );
                }

                String? nearestId;
                if (position != null) {
                  final location = ref.read(locationServiceProvider);
                  var best = double.infinity;
                  for (final t in titikList) {
                    final d = location.distanceMeters(
                      fromLat: position.latitude,
                      fromLng: position.longitude,
                      toLat: t.latitude,
                      toLng: t.longitude,
                    );
                    if (d < best) {
                      best = d;
                      nearestId = t.id;
                    }
                  }
                }

                return Column(
                  children: [
                    for (final t in titikList)
                      _TitikTile(
                        titik: t,
                        distanceText: position == null
                            ? null
                            : _formatDistance(ref
                                .read(locationServiceProvider)
                                .distanceMeters(
                                  fromLat: position.latitude,
                                  fromLng: position.longitude,
                                  toLat: t.latitude,
                                  toLng: t.longitude,
                                )),
                        isNearest: t.id == nearestId,
                        isSelected: t.id == selectedId,
                        onTap: () => _selectTitik(t),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Pintu masuk Formulir Lapangan (Fase A1.5) — navigasi tetap dibuka,
/// layar formulir sendiri yang memblokir bila belum check-in.
class _FormulirEntryPoint extends ConsumerWidget {
  const _FormulirEntryPoint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.description_outlined,
            color: theme.colorScheme.primary),
        title: const Text('Formulir Lapangan'),
        subtitle:
            const Text('Laporan aktivitas harian terkait presensi.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FormulirScreen()),
        ),
      ),
    );
  }
}

class _PendingBadgeAction extends ConsumerWidget {
  const _PendingBadgeAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingCountProvider);

    return IconButton(
      tooltip: 'Aksi menunggu sinkronisasi',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.cloud_upload_outlined),
      ),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        await ref
            .read(outboxSyncServiceProvider)
            .syncNow(ignoreBackoff: true);
        messenger.showSnackBar(
          SnackBar(content: Text('Sinkronisasi selesai ($count tertunda).')),
        );
      },
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.loading,
    required this.problem,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final bool loading;
  final String? problem;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return Card(
        child: ListTile(
          leading: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: const Text('Mengambil lokasi…'),
          subtitle: const Text('Jarak ke titik dihitung setelah posisi siap.'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRetry,
          ),
        ),
      );
    }

    if (problem != null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        child: ListTile(
          leading: const Icon(Icons.location_off_outlined),
          title: const Text('Lokasi tidak tersedia'),
          subtitle: Text(problem!),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'retry', child: Text('Coba lagi')),
              PopupMenuItem(value: 'settings', child: Text('Pengaturan lokasi')),
            ],
            onSelected: (value) =>
                value == 'retry' ? onRetry() : onOpenSettings(),
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: Icon(Icons.my_location, color: theme.colorScheme.primary),
        title: const Text('Lokasi siap'),
        subtitle: const Text('Pilih titik kerja untuk check-in.'),
        trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: onRetry),
      ),
    );
  }
}

class _TitikTile extends StatelessWidget {
  const _TitikTile({
    required this.titik,
    required this.distanceText,
    required this.isNearest,
    required this.isSelected,
    required this.onTap,
  });

  final Titik titik;
  final String? distanceText;
  final bool isNearest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proyekLabel = titik.proyek;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: isSelected
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 2),
            )
          : null,
      child: ListTile(
        onTap: onTap,
        selected: isSelected,
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            isSelected ? Icons.place : Icons.location_on_outlined,
            size: 20,
          ),
        ),
        title: Text(titik.nama),
        subtitle: Text([
          if (proyekLabel != null && proyekLabel.isNotEmpty) proyekLabel,
          'Radius ${titik.radiusPresensiMeter.round()} m',
        ].join(' • ')),
        isThreeLine: true,
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isNearest)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Terdekat',
                  style: theme.textTheme.labelSmall,
                ),
              )
            else if (isSelected)
              Icon(Icons.check_circle,
                  color: theme.colorScheme.primary, size: 20),
            if (distanceText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  distanceText!,
                  style: theme.textTheme.labelLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
