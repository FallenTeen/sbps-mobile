import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/portal/portal_providers.dart';
import '../../features/update/stale_app_dialog.dart';
import '../../features/version/version_gate.dart';
import '../../shared/theme/app_theme.dart';

/// Tombol untuk kembali ke layar pemilihan portal.
/// Ditampilkan di AppBar setiap halaman.
///
/// Saat aplikasi kadaluwarsa (version gate), ditampilkan label permanen
/// "Aplikasi Kadaluwarsa" di sebelah tombol — klik membuka modal unduh.
class PortalSwitchButton extends ConsumerWidget {
  const PortalSwitchButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gate = ref.watch(versionGateProvider);
    final stale = gate.value?.blocked ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stale) ...[
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showStaleAppDialog(context, gate.value?.info),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colors.error.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'Aplikasi Kadaluwarsa',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          tooltip: 'Ganti portal',
          icon: const Icon(Icons.apps),
          onPressed: () => ref.read(selectedPortalProvider.notifier).clear(),
        ),
      ],
    );
  }
}
