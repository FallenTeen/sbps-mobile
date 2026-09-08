import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'models/notification.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'notifikasi_providers.dart';

/// Daftar notifikasi (Fase A1.7): status baca, tap → tandai dibaca,
/// lalu buka action_url bila ada.
class NotifikasiScreen extends ConsumerWidget {
  const NotifikasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          const PortalSwitchButton(),
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(notificationsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: async.when(
          loading: () => const SkeletonListView(itemCount: 6),
          error: (error, _) => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Notifikasi',
            subtitle: '$error',
            actionLabel: 'Coba Lagi',
            onAction: () =>
                ref.read(notificationsProvider.notifier).refresh(),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const AppEmptyState(
                icon: Icons.notifications_none,
                title: 'Belum Ada Notifikasi',
                subtitle: 'Pemberitahuan aktivitas dan sistem akan muncul di sini.',
              );
            }
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => StaggeredEntrance(
                  index: i,
                  child: _Tile(notification: page.items[i]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bold = !notification.isRead;

    TextStyle style(ThemeData t) => t.textTheme.bodyMedium!.copyWith(
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        );

    return Card(
      margin: EdgeInsets.zero,
      color: bold
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
          : null,
      child: ListTile(
        leading: Icon(
          notification.isRead
              ? Icons.notifications_outlined
              : Icons.notifications_active,
          color: notification.isRead
              ? theme.colorScheme.outline
              : theme.colorScheme.primary,
        ),
        title: Text(notification.title ?? '(Tanpa judul)',
            style: bold ? style(theme) : null),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((notification.body ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(notification.body!, style: style(theme)),
              ),
            if (notification.time != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(notification.time!,
                    style: theme.textTheme.labelSmall),
              ),
          ],
        ),
        trailing: bold
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () => _onTap(context, ref),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final error =
        await ref.read(notificationsProvider.notifier).markRead(notification);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.read(unreadCountProvider.notifier).reload();

    final url = notification.actionUrl;
    if (url == null || url.isEmpty || !context.mounted) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka tautan.')));
    }
  }
}
