import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'home_shell.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Home sementara Fase A1.2/A2.2: verifikasi sesi, role switch, dan
/// peringatan akun belum terhubung karyawan. Modul fitur menyusul per fase.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    ref.listen(sessionMessageProvider, (previous, next) {
      if (next != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next)));
        ref.read(sessionMessageProvider.notifier).consume();
      }
    });

    if (auth.isLoading || auth.value == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = auth.value!;
    final roles = user.roles;
    final activeRole = ref.watch(activeRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const HomeTitle(),
        actions: [
          const PortalSwitchButton(),
          if (roles.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: activeRole,
                  hint: const Text('Role'),
                  items: roles
                      .map(
                        (role) =>
                            DropdownMenuItem(value: role, child: Text(role)),
                      )
                      .toList(),
                  onChanged: (role) {
                    if (role != null) {
                      ref.read(activeRoleProvider.notifier).switchRole(role);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
              ),
              title: Text(user.name),
              subtitle: Text(user.email),
            ),
          ),
          if (!user.hasKaryawan) ...[
            const SizedBox(height: 8),
            MaterialBanner(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              contentTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              content: const Text(
                'Akun Anda belum terhubung ke data karyawan, hubungi admin.',
              ),
              actions: [
                const PortalSwitchButton(),
                TextButton(onPressed: () {}, child: const Text('Tutup')),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: roles.map((role) => Chip(label: Text(role))).toList(),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () async {
              final result = await confirmLogout(context);
              if (result?.confirmed == true) {
                ref.read(authControllerProvider.notifier).logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
