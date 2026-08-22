import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/notification.dart';
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
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(notificationsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Pesan(
          icon: Icons.cloud_off_outlined,
          judul: 'Gagal memuat notifikasi',
          detail: '$error',
          aksiLabel: 'Coba lagi',
          onAksi: () =>
              ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return const _Pesan(
              icon: Icons.notifications_none,
              judul: 'Belum ada notifikasi',
              detail: 'Pemberitahuan akan muncul di sini.',
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
              itemBuilder: (context, i) =>
                  _Tile(notification: page.items[i]),
            ),
          );
        },
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

class _Pesan extends StatelessWidget {
  const _Pesan({
    required this.icon,
    required this.judul,
    required this.detail,
    this.aksiLabel,
    this.onAksi,
  });

  final IconData icon;
  final String judul;
  final String detail;
  final String? aksiLabel;
  final VoidCallback? onAksi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(judul, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
            if (aksiLabel != null && onAksi != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                  onPressed: onAksi, child: Text(aksiLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
