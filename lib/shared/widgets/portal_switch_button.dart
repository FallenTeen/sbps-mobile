import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/portal/portal_providers.dart';

/// Tombol untuk kembali ke layar pemilihan portal.
/// Ditampilkan di AppBar setiap halaman.
class PortalSwitchButton extends ConsumerWidget {
  const PortalSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Ganti portal',
      icon: const Icon(Icons.apps),
      onPressed: () =>
          ref.read(selectedPortalProvider.notifier).clear(),
    );
  }
}
