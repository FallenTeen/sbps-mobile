import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_providers.dart';
import 'portal_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Halaman pemilih portal: Presensi atau Proyek.
/// Tampil setelah login jika user punya akses ke kedua portal.
class PortalSelectionScreen extends ConsumerWidget {
  const PortalSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final canPresensi = canAccessPresensi(user);
    final canProyek = canAccessProyek(user);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Pilih Portal'),
          actions: [
          const PortalSwitchButton(),
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Halo, ${user.name}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih portal yang ingin Anda gunakan.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            _PortalCard(
              icon: Icons.fingerprint,
              title: 'SBPS Presensi',
              subtitle: AppPortal.presensi.description,
              color: Colors.teal,
              enabled: canPresensi,
              disabledMessage: 'Anda tidak memiliki akses ke portal ini',
              onTap: () async {
                await ref
                    .read(selectedPortalProvider.notifier)
                    .select(AppPortal.presensi);
                if (context.mounted) context.go('/home');
              },
            ),
            const SizedBox(height: 16),
            _PortalCard(
              icon: Icons.engineering,
              title: 'SBPS Proyek',
              subtitle: AppPortal.proyek.description,
              color: Colors.indigo,
              enabled: canProyek,
              disabledMessage: 'Anda tidak memiliki akses ke portal ini',
              onTap: () async {
                await ref
                    .read(selectedPortalProvider.notifier)
                    .select(AppPortal.proyek);
                if (context.mounted) context.go('/home');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.enabled,
    required this.disabledMessage,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool enabled;
  final String disabledMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: enabled
                      ? color.withValues(alpha: 0.1)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: enabled
                      ? color
                      : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? null
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      enabled ? subtitle : disabledMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: enabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
