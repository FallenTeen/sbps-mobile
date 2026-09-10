import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/animated_badge.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../auth/auth_providers.dart';
import '../formulir/formulir_screen.dart';
import '../home/home_shell.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../notifikasi/notifikasi_screen.dart';
import '../titik/titik_selector.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPosition();
      ref.read(unreadCountProvider.notifier).reload();
    });
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
    final selectedTitik = ref.watch(selectedTitikProvider);
    final selectedId = selectedTitik?.id;

    return Scaffold(
      appBar: AppBar(
        title: const HomeTitle(),
        actions: [
          // Profil user
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
          const PortalSwitchButton(),
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
          const _NotifikasiBadgeAction(),
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
        child: ResponsiveCenter(
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

              Row(
                children: [
                  Icon(Icons.place_outlined,
                      size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('Titik Kerja Aktif',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 10),

              titikAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SkeletonListView(itemCount: 3, padding: EdgeInsets.zero),
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

                  return TitikSelector(
                    titikList: titikList,
                    selectedTitik: selectedTitik,
                    mapHeight: 360,
                    onChanged: (t) {
                      if (t != null) _selectTitik(t);
                    },
                    listBuilder: (context, _) => Column(
                      children: [
                        for (var i = 0; i < titikList.length; i++)
                          StaggeredEntrance(
                            index: i,
                            child: _TitikTile(
                              titik: titikList[i],
                              distanceText: position == null
                                  ? null
                                  : _formatDistance(ref
                                      .read(locationServiceProvider)
                                      .distanceMeters(
                                        fromLat: position.latitude,
                                        fromLng: position.longitude,
                                        toLat: titikList[i].latitude,
                                        toLng: titikList[i].longitude,
                                      )),
                              isNearest: titikList[i].id == nearestId,
                              isSelected: titikList[i].id == selectedId,
                              onTap: () => _selectTitik(titikList[i]),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
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

/// Lonceng notifikasi dengan badge unread (Fase A1.7). Badge di-refresh
/// saat kembali dari halaman notifikasi.
class _NotifikasiBadgeAction extends ConsumerWidget {
  const _NotifikasiBadgeAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);

    return IconButton(
      tooltip: 'Notifikasi',
      icon: AnimatedCountBadge(
        count: count,
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const NotifikasiScreen()),
        );
        ref.read(unreadCountProvider.notifier).reload();
      },
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
      icon: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedCountBadge(
            count: count,
            badgeColor: Colors.orange.shade700,
            child: const Icon(Icons.cloud_upload_outlined),
          ),
          if (count > 0)
            const Positioned(
              top: 2,
              right: 2,
              child: PulsingSyncDot(size: 6),
            ),
        ],
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
    final proyekLabel = titik.proyek;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryColor
              : isNearest
                  ? AppTheme.primaryColor.withValues(alpha: 0.3)
                  : AppTheme.borderColor,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Location icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : AppTheme.surfaceVariantColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? Icons.place_rounded : Icons.location_on_outlined,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titik.nama,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (proyekLabel != null && proyekLabel.isNotEmpty)
                        Text(
                          proyekLabel,
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        'Radius ${titik.radiusPresensiMeter.round()} m',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trailing badges
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isNearest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryColor, Color(0xFF14B8A6)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Terdekat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.primaryColor, size: 22),
                    if (distanceText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          distanceText!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
