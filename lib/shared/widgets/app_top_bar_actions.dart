import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/notifikasi/notifikasi_providers.dart';
import '../../features/portal/portal_providers.dart';
import 'animated_badge.dart';
import 'confirmation_dialog.dart';
import 'portal_switch_button.dart';
import 'sync_action_button.dart';

/// Konfirmasi ganti peran sebelum eksekusi.
Future<void> confirmRoleSwitch(
  BuildContext context,
  WidgetRef ref,
  String target,
  String? current,
) async {
  if (target == current) return;
  final result = await ConfirmationDialog.show(
    context,
    severity: ConfirmSeverity.warning,
    title: 'Bekerja sebagai $target?',
    message:
        'Role menentukan menu dan data yang tampil. Anda akan bekerja '
        'sebagai "$target" setelah pergantian ini.',
    confirmLabel: 'Ya, Gunakan $target',
    icon: Icons.swap_horiz_rounded,
  );
  if (result?.confirmed != true || !context.mounted) return;
  await ref.read(activeRoleProvider.notifier).switchRole(target);
}

/// Aksi seragam untuk top AppBar di seluruh halaman utama aplikasi.
///
/// Menyediakan akses konsisten untuk:
/// 1. Profil (`/profile`)
/// 2. Ganti portal (`PortalSwitchButton`)
/// 3. Sinkronisasi outbox (`SyncActionButton`)
/// 4. Notifikasi in-app dengan badge (`/notifikasi`)
/// 5. Ganti peran (bila user memiliki >1 peran App 2 dan sedang di portal Proyek)
/// 6. Logout (`confirmLogout`)
/// Serta mendukung aksi khusus layar via [extraLeadingActions] & [extraTrailingActions].
class AppTopBarActions extends ConsumerWidget {
  const AppTopBarActions({
    super.key,
    this.extraLeadingActions = const [],
    this.extraTrailingActions = const [],
    this.showProfile = true,
    this.showPortalSwitch = true,
    this.showSync = true,
    this.showNotification = true,
    this.showRoleSwitch = true,
    this.showLogout = true,
  });

  /// Aksi khusus halaman sebelum menu standar (mis. Riwayat Presensi pada Presensi, Riwayat QC pada QC).
  final List<Widget> extraLeadingActions;

  /// Aksi khusus halaman setelah menu standar (mis. overflow popup menu).
  final List<Widget> extraTrailingActions;

  final bool showProfile;
  final bool showPortalSwitch;
  final bool showSync;
  final bool showNotification;
  final bool showRoleSwitch;
  final bool showLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final role = ref.watch(activeRoleProvider);
    final portal = ref.watch(selectedPortalProvider).value;
    final roles = user == null ? <String>[] : app2RolesOf(user);
    final count = ref.watch(unreadCountProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...extraLeadingActions,
        if (showProfile)
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
        if (showPortalSwitch)
          const PortalSwitchButton(),
        if (showSync)
          const SyncActionButton(),
        if (showNotification)
          IconButton(
            tooltip: 'Notifikasi',
            icon: AnimatedCountBadge(
              count: count,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () {
              context.go('/notifikasi');
              ref.read(unreadCountProvider.notifier).reload();
            },
          ),
        if (showRoleSwitch && roles.length > 1 && portal == AppPortal.proyek)
          PopupMenuButton<String>(
            tooltip: 'Ganti peran',
            icon: const Icon(Icons.swap_horiz),
            onSelected: (r) => confirmRoleSwitch(context, ref, r, role),
            itemBuilder: (context) => [
              for (final r in roles)
                CheckedPopupMenuItem<String>(
                  value: r,
                  checked: r == role,
                  child: Text(r),
                ),
            ],
          ),
        if (showLogout)
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
        ...extraTrailingActions,
      ],
    );
  }
}
