import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/portal/portal_providers.dart';

/// Tombol untuk kembali ke layar pemilihan portal.
/// Hanya ditampilkan jika user memiliki akses ke lebih dari satu portal.
/// Gunakan sebagai salah satu `actions` di AppBar.
class PortalSwitchButton extends ConsumerWidget {
  const PortalSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    if (user == null || autoPortal(user) != null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Kembali ke portal',
      icon: const Icon(Icons.apps),
      onPressed: () =>
          ref.read(selectedPortalProvider.notifier).clear(),
    );
  }
}
