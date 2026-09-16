import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/animated_badge.dart';
import '../../shared/widgets/brand_strip.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/info_tooltip.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/sync_action_button.dart';
import '../auth/auth_providers.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../home/home_shell.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../titik/titik_selector.dart';
import 'models/titik.dart';
import 'presensi_hari_ini_card.dart';
import 'presensi_providers.dart';

/// Fase A1.3 — daftar titik kerja aktif dengan jarak GPS ke tiap titik,
/// penanda titik terdekat, dan pemilihan titik untuk alur check-in (A1.4).
class TitikKerjaScreen extends ConsumerStatefulWidget {
  const TitikKerjaScreen({super.key});

  @override
  ConsumerState<TitikKerjaScreen> createState() => _TitikKerjaScreenState();
}

class _TitikKerjaScreenState extends ConsumerState<TitikKerjaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(locationProvider.notifier).refresh();
      ref.read(unreadCountProvider.notifier).reload();
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${fmtNum(meters / 1000)} km';
  }

  Future<void> _refreshAll() async {
    ref.invalidate(titikAktifProvider);
    ref.invalidate(assignmentsProvider);
    await ref.read(locationProvider.notifier).refresh();
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
    final location = ref.watch(locationProvider);
    final position = location.position;
    final selectedTitik = ref.watch(selectedTitikProvider);
    final selectedId = selectedTitik?.id;

    return Scaffold(
      appBar: AppBar(
        title: const HomeTitle(),
        bottom: const BrandStrip(),
        actions: [
          // Profil user
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
          PortalSwitchButton(),
          IconButton(
            tooltip: 'Riwayat presensi',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/presensi/riwayat'),
          ),
          const _PendingBadgeAction(),
          const _NotifikasiBadgeAction(),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final result = await confirmLogout(context);
              if (result?.confirmed == true) {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
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
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  contentTextStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  content: const Text(
                    'Akun Anda belum terhubung ke data karyawan, hubungi admin.',
                  ),
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Tutup')),
                  ],
                ),
                const SizedBox(height: 8),
              ] else if (assignmentsAsync.value != null &&
                  assignmentsAsync.value!.isEmpty &&
                  assignmentsAsync.hasValue) ...[
                MaterialBanner(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  content: const Text('Belum ada penugasan, hubungi admin.'),
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Tutup')),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              const PresensiHariIniCard(),
              const _FormulirEntryPoint(),
              _LocationCard(
                location: location,
                onOpenSettings: () =>
                    ref.read(locationServiceProvider).openSettings(),
                onRefresh: () =>
                    ref.read(locationProvider.notifier).refresh(),
              ),
              SizedBox(height: 16),

              Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 20,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Titik Kerja Aktif',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  InfoTooltip(
                    message:
                        'Menandai titik kerja paling dekat dengan lokasi Anda saat ini.',
                  ),
                ],
              ),
              const SizedBox(height: 10),

              titikAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SkeletonListView(
                    itemCount: 3,
                    padding: EdgeInsets.zero,
                  ),
                ),
                error: (error, _) => Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: const Text('Gagal memuat titik kerja'),
                    subtitle: Text(friendlyErrorMessage(error)),
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
                    userPosition: position == null
                        ? null
                        : LatLng(position.latitude, position.longitude),
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
                                  : _formatDistance(
                                      ref
                                          .read(locationServiceProvider)
                                          .distanceMeters(
                                            fromLat: position.latitude,
                                            fromLng: position.longitude,
                                            toLat: titikList[i].latitude,
                                            toLng: titikList[i].longitude,
                                          ),
                                    ),
                              isLuarRadius:
                                  position == null
                                      ? null
                                      : ref
                                              .read(locationServiceProvider)
                                              .distanceMeters(
                                                fromLat: position.latitude,
                                                fromLng: position.longitude,
                                                toLat: titikList[i].latitude,
                                                toLng: titikList[i].longitude,
                                              ) >
                                          titikList[i].radiusPresensiMeter,
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
        leading: Icon(
          Icons.description_outlined,
          color: theme.colorScheme.primary,
        ),
        title: const Text('Formulir Lapangan'),
        subtitle: const Text('Laporan aktivitas harian terkait presensi.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/formulir'),
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
      onPressed: () {
        context.go('/notifikasi');
        ref.read(unreadCountProvider.notifier).reload();
      },
    );
  }
}

class _PendingBadgeAction extends ConsumerWidget {
  const _PendingBadgeAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SyncActionButton();
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.onOpenSettings,
    required this.onRefresh,
  });

  final LocationSnapshot location;
  final VoidCallback onOpenSettings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Belum pernah dapat posisi + sedang mengambil.
    if (location.loading && !location.hasPosition) {
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
            onPressed: onRefresh,
          ),
        ),
      );
    }

    if (location.problem != null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        child: ListTile(
          leading: const Icon(Icons.location_off_outlined),
          title: const Text('Lokasi tidak tersedia'),
          subtitle: Text(location.problemLabel ?? ''),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            itemBuilder: (context) => [
              PopupMenuItem(value: 'retry', child: Text('Coba lagi')),
              PopupMenuItem(
                value: 'settings',
                child: Text('Pengaturan lokasi'),
              ),
            ],
            onSelected: (value) =>
                value == 'retry' ? onRefresh() : onOpenSettings(),
          ),
        ),
      );
    }

    // Ada posisi tapi sudah basi → minta segarkan sebelum check-in.
    if (location.hasPosition && location.isStale) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(Icons.schedule, color: theme.colorScheme.tertiary),
          title: const Text('Posisi GPS sudah lama'),
          subtitle: const Text(
            'Lokasi terakhir diambil lebih dari 10 menit lalu. Segarkan untuk melacak posisi Anda. Check-in tidak aktif sampai posisi segar.',
          ),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: 'Segarkan lokasi',
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ),
      );
    }

    // Siap (dengan/atau sedang mengambil ulang dengan posisi tersimpan).
    return Card(
      child: ListTile(
        leading: Icon(Icons.my_location, color: theme.colorScheme.primary),
        title: const Text('Lokasi siap'),
        subtitle: Text(
          location.loading
              ? 'Memperbarui lokasi…'
              : 'Pilih titik kerja untuk check-in.',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
        ),
      ),
    );
  }
}

class _TitikTile extends StatelessWidget {
  const _TitikTile({
    required this.titik,
    required this.distanceText,
    required this.isLuarRadius,
    required this.isNearest,
    required this.isSelected,
    required this.onTap,
  });

  final Titik titik;
  final String? distanceText;

  /// null = posisi belum tersedia; false = dalam radius; true = luar radius.
  final bool? isLuarRadius;
  final bool isNearest;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final proyekLabel = titik.proyek;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected
            ? context.colors.primary.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? context.colors.primary
              : isNearest
              ? context.colors.primary.withValues(alpha: 0.3)
              : context.colors.border,
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
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                // Location icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colors.primary.withValues(alpha: 0.1)
                        : context.colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.place_rounded
                        : Icons.location_on_outlined,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.textTertiary,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
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
                              ? context.colors.primary
                              : context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (proyekLabel != null && proyekLabel.isNotEmpty)
                        Text(
                          proyekLabel,
                          style: TextStyle(
                            color: context.colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        'Radius ${titik.radiusPresensiMeter.round()} m',
                        style: TextStyle(
                          color: context.colors.textMuted,
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
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Terpilih',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (isNearest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
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
                      ),
                    if (distanceText != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          distanceText!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      if (isLuarRadius != null) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isLuarRadius!
                                ? context.colors.warning.withValues(alpha: 0.15)
                                : context.colors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isLuarRadius! ? 'Luar radius' : 'Dalam radius',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isLuarRadius!
                                  ? context.colors.warning
                                  : context.colors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
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
