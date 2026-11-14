import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show LocationPermission;
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_top_bar_actions.dart';
import '../../shared/widgets/brand_strip.dart';import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/info_banner.dart';
import '../../shared/widgets/info_tooltip.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/submit_spinner.dart';
import '../auth/auth_providers.dart';
import '../home/home_shell.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../titik/titik_selector.dart';
import '../tracking/battery_guide_sheet.dart';
import '../tracking/tracking_providers.dart';
import 'models/presensi_hari_ini.dart';
import 'models/titik.dart';
import 'presensi_hari_ini_card.dart';
import 'presensi_providers.dart';

/// Daftar titik kerja aktif dengan jarak GPS ke tiap titik,
/// penanda titik terdekat, dan pemilihan titik untuk alur check-in.
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
    final pending = ref.watch(pendingPresensiProvider);
    final presensiStatus = ref.watch(hariIniProvider).value?.status;
    final presensiOpen =
        presensiStatus == PresensiStatus.menungguCheckOut ||
        pending.checkInPending;

    return Scaffold(
      appBar: AppBar(
        title: const HomeTitle(),
        bottom: const BrandStrip(),
        actions: [
          AppTopBarActions(
            extraLeadingActions: [
              IconButton(
                tooltip: 'Riwayat presensi',
                icon: const Icon(Icons.history),
                onPressed: () => context.push('/presensi/riwayat'),
              ),
            ],
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
                const InfoBanner(
                  icon: Icons.warning_amber_rounded,
                  message:
                      'Akun Anda belum terhubung ke data karyawan, hubungi admin.',
                ),
                const SizedBox(height: 8),
              ] else if (assignmentsAsync.value != null &&
                  assignmentsAsync.value!.isEmpty &&
                  assignmentsAsync.hasValue) ...[
                const InfoBanner(
                  message: 'Belum ada penugasan, hubungi admin.',
                ),
                const SizedBox(height: 8),
              ],

              const PresensiHariIniCard(),
              if (pending.checkInPending) ...[
                const SizedBox(height: 8),
                const InfoBanner(
                  icon: Icons.cloud_off_outlined,
                  message:
                      'Presensi Anda menunggu koneksi internet, akan terkirim otomatis.',
                ),
              ],
              if (presensiOpen) ...[
                const SizedBox(height: 8),
                const _TrackingStatusStrip(),
                const SizedBox(height: 8),
                const _AlwaysPermissionBanner(),
              ],
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

/// Pintu masuk Formulir Lapangan - navigasi tetap dibuka,
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
            child: SubmitSpinner(),
          ),
          title: const Text('Mengambil lokasi…'),
          subtitle: const Text('Jarak ke titik dihitung setelah posisi siap.'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Perbarui lokasi',
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
          tooltip: 'Perbarui lokasi',
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
            : context.colors.card,
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
                            fontSize: 11,
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
                            fontSize: 11,
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
                              fontSize: 11,
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

/// Detail pesan untuk strip status pemantauan. Pesan generik stop scheduler
/// disembunyikan agar tidak dobel dengan teks utama strip.
String? trackingStripDetail(String? schedulerMessage) {
  if (schedulerMessage == null || schedulerMessage.isEmpty) return null;
  if (schedulerMessage == 'Tracking tidak aktif.') return null;
  return schedulerMessage;
}

  /// Strip status pemantauan lokasi - tampil hanya saat
/// presensi terbuka. Meniru gaya [_GpsStatusStrip] pada kartu presensi.
class _TrackingStatusStrip extends ConsumerWidget {
  const _TrackingStatusStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(trackingSchedulerProvider);
    final colors = context.colors;
    final running = status.running;

    final pesan = running
        ? (status.pendingPoints > 0
              ? 'Pemantauan lokasi aktif, menunggu kirim: ${status.pendingPoints} titik.'
              : 'Pemantauan lokasi aktif.')
        : 'Pemantauan lokasi tidak aktif.';
    final detail = running ? null : trackingStripDetail(status.message);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: running
            ? colors.success.withValues(alpha: 0.1)
            : colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            running ? Icons.my_location : Icons.location_off_outlined,
            size: 18,
            color: running ? colors.success : colors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pesan,
                  style: TextStyle(
                    color: running ? colors.success : colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail,
                    style: TextStyle(
                      color: colors.error,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                if (!running)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: () => showBatteryGuideSheet(context),
                      child: Text(
                        'Panduan baterai',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panduan izin lokasi Sepanjang Waktu - tampil saat presensi terbuka tapi
/// izin masih while-in-use atau ditolak permanen. Tanpa persistensi:
/// cukup cek sekali saat layar dibuka dan saat kembali dari pengaturan.
enum _AlwaysPromptState { none, upgrade, deniedForever }

class _AlwaysPermissionBanner extends ConsumerStatefulWidget {
  const _AlwaysPermissionBanner();

  @override
  ConsumerState<_AlwaysPermissionBanner> createState() =>
      _AlwaysPermissionBannerState();
}

class _AlwaysPermissionBannerState
    extends ConsumerState<_AlwaysPermissionBanner>
    with WidgetsBindingObserver {
  _AlwaysPromptState _prompt = _AlwaysPromptState.none;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final service = ref.read(locationServiceProvider);
    LocationPermission permission;
    try {
      permission = await service.currentPermission();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _prompt = switch (permission) {
        LocationPermission.whileInUse => _AlwaysPromptState.upgrade,
        LocationPermission.deniedForever => _AlwaysPromptState.deniedForever,
        _ => _AlwaysPromptState.none,
      };
    });
  }

  void _openSettings() {
    ref.read(locationServiceProvider).openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _prompt == _AlwaysPromptState.none) {
      return const SizedBox.shrink();
    }

    final pesan = _prompt == _AlwaysPromptState.upgrade
        ? 'Aktifkan izin lokasi Sepanjang Waktu agar lokasi tetap terkirim saat aplikasi ditutup.'
        : 'Izin lokasi ditolak permanen. Buka Pengaturan untuk mengaktifkan.';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_searching,
            size: 18,
            color: context.colors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pesan,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _openSettings,
            child: const Text('Buka Pengaturan'),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Tutup',
            icon: Icon(Icons.close, size: 18, color: context.colors.textTertiary),
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}
