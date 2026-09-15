import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_providers.dart';
import '../../shared/widgets/confirmation_dialog.dart';

/// Halaman pemilih role aktif (Fase A2.2): tampil setelah login bila user
/// punya lebih dari satu role App 2. Tidak bisa di-back (wajib pilih).
class RolePickerScreen extends ConsumerWidget {
  const RolePickerScreen({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, String role) async {
    await ref.read(activeRoleProvider.notifier).switchRole(role);
    ref.read(roleChoicePendingProvider.notifier).set(false);
    if (context.mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final roles = user == null ? const <String>[] : app2RolesOf(user);
    final active = ref.watch(activeRoleProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Pilih Peran'),
        ),
        body: roles.isEmpty
            ? _NoRoleView(
                onLogout: () async {
                  final result = await confirmLogout(context);
                  if (result?.confirmed == true) {
                    ref.read(authControllerProvider.notifier).logout();
                  }
                },
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Halo ${user!.name}, akun Anda punya beberapa peran. '
                    'Pilih peran yang ingin dipakai sekarang.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  for (final role in roles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Card(
                        elevation: role == active ? 4 : 1,
                        child: ListTile(
                          leading: Icon(
                            _iconForRole(role),
                            size: 32,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            role,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(_descriptionForRole(role)),
                          trailing: role == active
                              ? const Icon(Icons.check_circle)
                              : const Icon(Icons.chevron_right),
                          onTap: () => _choose(context, ref, role),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _NoRoleView extends StatelessWidget {
  const _NoRoleView({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Akun ini belum memiliki peran Mandor Titik, Kontraktor, '
              'Owner, atau Admin Keuangan.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onLogout,
              child: const Text('Keluar'),
            ),
          ],
        ),
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
    default:
      return Icons.badge;
  }
}

String _descriptionForRole(String role) {
  switch (role) {
    case 'Mandor Titik':
      return 'Sesi produksi, QC, dan progres titik';
    case 'Kontraktor':
      return 'Dashboard operasional non-finansial';
    case 'Owner':
      return 'Akses penuh termasuk finansial';
    case 'Admin Keuangan':
      return 'Dashboard finansial dan tracking';
    default:
      return '';
  }
}
