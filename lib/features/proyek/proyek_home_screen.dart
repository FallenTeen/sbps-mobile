import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import '../notifikasi/notifikasi_providers.dart';
import '../notifikasi/notifikasi_screen.dart';
import '../portal/portal_providers.dart';
import '../tracking/tracking_providers.dart';
import 'role_permissions.dart';

/// Home App 2 per role aktif (Fase A2.2): tile modul difilter permission
/// matrix, dan dropdown switch role cepat tanpa logout di app bar.
class ProyekHomeScreen extends ConsumerWidget {
  const ProyekHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final role = ref.watch(activeRoleProvider);
    final roles = user == null ? const <String>[] : app2RolesOf(user);
    final allowed = kProyekModules
        .where((m) => RolePermissions.canAccess(role, m.key))
        // Viewer tracking khusus Owner/Admin Keuangan (sembunyikan menu).
        .where((m) => m.key != 'tracking' || RolePermissions.isAdminLike(role))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${user?.name ?? ''}'),
        actions: [
          // Kembali ke layar pilihan portal (hanya bila user punya >1 portal).
          if (user != null && autoPortal(user) == null)
            IconButton(
              tooltip: 'Pilih portal',
              icon: const Icon(Icons.apps),
              onPressed: () => ref
                  .read(selectedPortalProvider.notifier)
                  .clear(),
            ),
          // Profil user — edit profil & logout semua perangkat.
          IconButton(
            tooltip: 'Profil',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
          // Lonceng notifikasi + badge unread — reuse modul A1.7 (A2.8).
          const _NotifikasiBadgeAction(),
          if (roles.length > 1)
            PopupMenuButton<String>(
              tooltip: 'Ganti peran',
              icon: const Icon(Icons.swap_horiz),
              onSelected: (r) =>
                  ref.read(activeRoleProvider.notifier).switchRole(r),
              itemBuilder: (context) => [
                for (final r in roles)
                  CheckedPopupMenuItem<String>(
                    value: r,
                    checked: r == role,
                    child: Text(r),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: role == null
          ? _NoActiveRoleView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (role == 'Mandor Titik') ...[
                  const _TrackingStatusCard(),
                  const SizedBox(height: 8),
                ],
                Chip(
                  avatar: Icon(_iconForRole(role), size: 18),
                  label: Text('Peran aktif: $role'),
                ),
                const SizedBox(height: 8),
                for (final module in allowed)
                  Card(
                    child: ListTile(
                      leading: Icon(module.icon, size: 32),
                      title: Text(
                        module.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: switch (module.key) {
                        'produksi' => const Text(
                            'Sesi aktif, mulai, riwayat, progress, QC'),
                        'qc' => const Text(
                            'Slump test & uji tekan, riwayat QC'),
                        'tracking' => const Text(
                            'User aktif & jejak lokasi'),
                        'dashboard' =>
                          const Text('Ringkasan titik & operasional'),
                        'keuangan' =>
                          const Text('Chart keuangan, PO, invoice'),
                        'armada' =>
                          const Text('Kendaraan, ritase & checklist harian'),
                        _ => const Text('Menyusul di fase berikutnya'),
                      },
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        switch (module.key) {
                          case 'produksi':
                            context.push('/produksi/sesi-aktif');
                          case 'qc':
                            context.push('/qc/riwayat');
                          case 'tracking':
                            context.push('/tracking/pengguna-aktif');
                          case 'dashboard':
                            context.push('/dashboard');
                          case 'keuangan':
                            context.push('/dashboard/keuangan');
                          case 'armada':
                            context.push('/armada');
                          default:
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('${module.label} belum tersedia')),
                            );
                        }
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

IconData _iconForRole(String role) {
  switch (role) {
    case 'Mandor Titik':
      return Icons.engineering;
    case 'Kontraktor':
      return Icons.business_center;
    case 'Admin Keuangan':
      return Icons.account_balance_wallet;
    case 'Owner':
      return Icons.supervisor_account;
    case 'Driver Armada':
      return Icons.local_shipping;
    default:
      return Icons.badge;
  }
}

/// Lonceng notifikasi dengan badge unread — reuse modul App 1
/// (Fase A2.8). Badge di-refresh saat kembali dari halaman notifikasi.
class _NotifikasiBadgeAction extends ConsumerWidget {
  const _NotifikasiBadgeAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadCountProvider);

    return IconButton(
      tooltip: 'Notifikasi',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
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

/// Status Live Tracking untuk Mandor Titik (Fase A2.4).
class _TrackingStatusCard extends ConsumerWidget {
  const _TrackingStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(trackingSchedulerProvider);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              status.running ? Icons.location_on : Icons.location_off,
              color: status.running ? Colors.green : theme.colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.running
                      ? 'Lokasi dipantau untuk keperluan kerja'
                      : 'Tracking tidak aktif'),
                  if (status.message != null)
                    Text(status.message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error)),
                ],
              ),
            ),
            if (status.pendingPoints > 0)
              Chip(label: Text('${status.pendingPoints} titik antre')),
          ],
        ),
      ),
    );
  }
}

class _NoActiveRoleView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 48),
            SizedBox(height: 12),
            Text(
              'Peran aktif tidak tersedia untuk App Proyek.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
