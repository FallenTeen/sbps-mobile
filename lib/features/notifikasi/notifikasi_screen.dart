import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/date_grouping.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/notification_routes.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/rich_list_tile.dart';
import '../../shared/widgets/searchable_list_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/formatters.dart';
import 'models/notification.dart';
import 'notifikasi_providers.dart';

/// Daftar notifikasi: status baca, tap → tandai dibaca lalu navigasi ke layar
/// terkait (deep-link internal, bukan browser eksternal). Tersedia filter
/// Semua/Belum Dibaca, "Tandai Semua Dibaca", dan pengelompokan tanggal.
class NotifikasiScreen extends ConsumerStatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  ConsumerState<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends ConsumerState<NotifikasiScreen> {
  bool _unreadOnly = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          const PortalSwitchButton(),
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(notificationsProvider.notifier).refresh(),
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
            onAction: () => ref.read(notificationsProvider.notifier).refresh(),
          ),
          data: (page) => _buildList(context, page),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, NotificationsPage page) {
    final q = _searchQuery.toLowerCase();
    final searched = q.isEmpty
        ? page.items
        : page.items
              .where(
                (n) =>
                    (n.title ?? '').toLowerCase().contains(q) ||
                    (n.body ?? '').toLowerCase().contains(q),
              )
              .toList();

    final visible = _unreadOnly
        ? searched.where((n) => !n.isRead).toList()
        : searched;

    if (page.items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_none,
        title: 'Belum Ada Notifikasi',
        subtitle: 'Pemberitahuan aktivitas dan sistem akan muncul di sini.',
      );
    }
    if (searched.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_outlined,
        title: 'Tidak Ada Hasil Pencarian',
        subtitle: 'Tidak ditemukan notifikasi yang cocok dengan pencarian.',
      );
    }
    if (visible.isEmpty) {
      return const AppEmptyState(
        icon: Icons.done_all,
        title: 'Semua Sudah Dibaca',
        subtitle: 'Tidak ada notifikasi baru yang belum dibuka.',
      );
    }

    final unreadCount = page.items.where((n) => !n.isRead).length;
    final rows = _buildRows(visible);

    return Column(
      children: [
        SearchableListHeader(
          hintText: 'Cari notifikasi...',
          onChanged: (v) => setState(() => _searchQuery = v),
          child: _FilterBar(
            unreadOnly: _unreadOnly,
            unreadCount: unreadCount,
            onChanged: (value) => setState(() => _unreadOnly = value),
            onMarkAll: unreadCount == 0
                ? null
                : () => ref.read(notificationsProvider.notifier).markAllRead(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                if (row is _HeaderRow) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  );
                }
                final notification = (row as _TileRow).notification;
                return StaggeredEntrance(
                  index: i,
                  child: _Tile(notification: notification),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Susun baris list dengan header pengelompokan tanggal.
  List<Object> _buildRows(List<AppNotification> items) {
    final rows = <Object>[];
    String? lastHeader;
    for (final n in items) {
      final dt = DateTime.tryParse(n.time ?? '');
      final header = dt == null ? 'Lebih Lama' : dateGroupLabel(dt);
      if (header != lastHeader) {
        rows.add(_HeaderRow(header));
        lastHeader = header;
      }
      rows.add(_TileRow(n));
    }
    return rows;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.unreadOnly,
    required this.unreadCount,
    required this.onChanged,
    required this.onMarkAll,
  });

  final bool unreadOnly;
  final int unreadCount;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('Semua'),
            selected: !unreadOnly,
            onSelected: (_) => onChanged(false),
          ),
          ChoiceChip(
            label: Text('Belum Dibaca ($unreadCount)'),
            selected: unreadOnly,
            onSelected: (_) => onChanged(true),
          ),
          TextButton.icon(
            onPressed: onMarkAll,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Tandai semua'),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow {
  const _HeaderRow(this.label);
  final String label;
}

class _TileRow {
  const _TileRow(this.notification);
  final AppNotification notification;
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final unread = !notification.isRead;

    return RichListTile(
      title: notification.title ?? '(Tanpa judul)',
      subtitle: (notification.body ?? '').isNotEmpty ? notification.body : null,
      meta: notification.time != null ? fmtRelatif(notification.time!) : null,
      metaColor: colors.textTertiary,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (unread ? colors.primary : colors.textMuted).withValues(
            alpha: 0.12,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          unread ? Icons.notifications_active : Icons.notifications_outlined,
          size: 20,
          color: unread ? colors.primary : colors.textMuted,
        ),
      ),
      trailing: unread
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            )
          : null,
      onTap: () => _onTap(context, ref),
    );
  }

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    final error = await ref
        .read(notificationsProvider.notifier)
        .markRead(notification);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ref.read(unreadCountProvider.notifier).reload();

    final actionUrl = notification.actionUrl;
    if (actionUrl == null || actionUrl.isEmpty || !context.mounted) return;

    final route = notificationActionRoute(actionUrl);
    if (route != null) {
      // Deep-link internal: push (bukan go) supaya back stack tetap utuh —
      // user bisa kembali ke daftar notifikasi.
      try {
        context.push(route);
      } on StateError {
        messenger.showSnackBar(
          const SnackBar(content: Text('Layar terkait belum tersedia.')),
        );
      }
      return;
    }

    // Bukan tautan internal — buka eksternal sebagai fallback.
    final uri = Uri.tryParse(actionUrl);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka tautan.')),
      );
    }
  }
}
