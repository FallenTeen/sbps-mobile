import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/date_grouping.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/adaptive_master_detail.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/notification_routes.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/rich_list_tile.dart';
import '../../shared/widgets/searchable_list_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/utils/feedback_service.dart';
import '../auth/auth_providers.dart';
import 'models/notification.dart';
import 'notifikasi_providers.dart';

/// Pusat notifikasi (action center): filter kategori
/// (Approval/Servis/Stok/Produksi/Presensi/Formulir/Sistem), status baca,
/// dan tap -> markRead lalu navigasi deep-link ke layar terkait. Destination
/// yang tidak dikenali / tanpa hak akses tetap dibuka secara jelas (pesan
/// snackbar) - bukan diam.
class NotifikasiScreen extends ConsumerStatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  ConsumerState<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends ConsumerState<NotifikasiScreen> {
  bool _unreadOnly = false;
  String _searchQuery = '';
  NotificationCategory? _category;

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
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (value) {
              switch (value) {
                case 'mark_all':
                  ref.read(notificationsProvider.notifier).markAllRead();
                  FeedbackService.success(
                    context,
                    'Semua notifikasi ditandai dibaca.',
                  );
                  break;
                case 'clear_filter':
                  setState(() {
                    _category = null;
                    _unreadOnly = false;
                    _searchQuery = '';
                  });
                  break;
                case 'refresh':
                  ref.read(notificationsProvider.notifier).refresh();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'mark_all',
                child: Text('Tandai semua dibaca'),
              ),
              PopupMenuItem(
                value: 'clear_filter',
                child: Text('Bersihkan filter'),
              ),
              PopupMenuItem(value: 'refresh', child: Text('Segarkan')),
            ],
          ),
        ],
      ),
      body: ResponsiveCenter(
        child: async.when(
          loading: () => const SkeletonListView(itemCount: 6),
          error: (error, _) => AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Notifikasi',
            subtitle: friendlyErrorMessage(error),
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

    final filtered = searched.where(
      (n) => _category == null || n.category == _category,
    );
    final visible = _unreadOnly
        ? filtered.where((n) => !n.isRead).toList()
        : filtered.toList();

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
    if (filtered.isEmpty) {
      return AppEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: _category == null
            ? 'Semua Sudah Dibaca'
            : 'Belum Ada Notifikasi ${_category!.label}',
        subtitle: _category == null
            ? 'Tidak ada notifikasi baru yang belum dibuka.'
            : 'Silakan cek kategori lain atau segarkan daftar.',
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

    AppNotification notificationFor(String id) => page.items.firstWhere(
      (n) => n.id == id,
      orElse: () => page.items.first,
    );

    return AdaptiveMasterDetail(
      pushRouteFor: (id) {
        final destination = resolveNotificationDestination(
          notification: notificationFor(id),
          role: ref.read(activeRoleProvider),
        );
        return destination.route ?? '/notifikasi';
      },
      emptyDetailPlaceholder: const MasterDetailEmptyPlaceholder(
        icon: Icons.notifications_none,
        title: 'Pilih notifikasi',
        subtitle: 'Detail notifikasi & tujuan tautan tampil di sini',
      ),
      detailBuilder: (context, id) =>
          _NotificationDetail(notification: notificationFor(id)),
      masterBuilder: (context, selectedId, onSelect) => Column(
        children: [
          SearchableListHeader(
            hintText: 'Cari notifikasi...',
            onChanged: (v) => setState(() => _searchQuery = v),
            child: _FilterBar(
              category: _category,
              unreadOnly: _unreadOnly,
              unreadCount: unreadCount,
              items: page.items,
              onCategory: (c) => setState(() => _category = c),
              onUnreadOnly: (value) => setState(() => _unreadOnly = value),
              onMarkAll: unreadCount == 0
                  ? null
                  : () =>
                        ref.read(notificationsProvider.notifier).markAllRead(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: _buildSlivers(visible, (notification) {
                  // Only the expanded two-pane layout owns selection locally.
                  // Compact/medium must keep using the normal push flow;
                  // pushing '/notifikasi' here duplicates the GoRouter page key.
                  if (!context.isExpanded) return false;
                  onSelect(notification.id);
                  return true;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Susun sliver dengan header tanggal yang menempel saat scroll.
  List<Widget> _buildSlivers(
    List<AppNotification> items,
    bool Function(AppNotification) onSelect,
  ) {
    final slivers = <Widget>[];
    final group = <AppNotification>[];
    String? header;

    void flush() {
      if (group.isEmpty || header == null) return;
      final label = header;
      final notifications = List<AppNotification>.unmodifiable(group);
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: _DateHeaderDelegate(label: label),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => StaggeredEntrance(
                index: i,
                child: _SwipeTile(
                  notification: notifications[i],
                  onSelected: onSelect,
                ),
              ),
              childCount: notifications.length,
            ),
          ),
        ),
      );
      group.clear();
    }

    for (final n in items) {
      final dt = DateTime.tryParse(n.time ?? '');
      final label = dt == null ? 'Lebih Lama' : dateGroupLabel(dt);
      if (label != header) {
        flush();
        header = label;
      }
      group.add(n);
    }
    flush();
    return slivers;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.category,
    required this.unreadOnly,
    required this.unreadCount,
    required this.items,
    required this.onCategory,
    required this.onUnreadOnly,
    required this.onMarkAll,
  });

  final NotificationCategory? category;
  final bool unreadOnly;
  final int unreadCount;
  final List<AppNotification> items;
  final ValueChanged<NotificationCategory?> onCategory;
  final ValueChanged<bool> onUnreadOnly;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final counts = <NotificationCategory, int>{};
    for (final n in items) {
      counts.update(n.category, (v) => v + 1, ifAbsent: () => 1);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text('Semua (${items.length})'),
                selected: category == null,
                onSelected: (_) => onCategory(null),
              ),
              for (final c in NotificationCategory.values) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: Icon(
                    categoryVisual(c).icon,
                    size: 16,
                    color: categoryVisual(c).color,
                  ),
                  label: Text('${c.label} (${counts[c] ?? 0})'),
                  selected: category == c,
                  onSelected: (_) => onCategory(c),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: Text('Belum Dibaca ($unreadCount)'),
              selected: unreadOnly,
              onSelected: (v) => onUnreadOnly(v),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onMarkAll,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tandai semua'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Visual kategori: ikon + warna. Dipisah di layar (bukan di model) supaya
/// enum model tetap bebas Flutter dan mudah diuji.
class CategoryVisual {
  const CategoryVisual(this.icon, this.color);
  final IconData icon;
  final Color color;
}

CategoryVisual categoryVisual(NotificationCategory c) {
  // Dipanggil dalam build - warna mengikuti tema via context.
  switch (c) {
    case NotificationCategory.approval:
      return CategoryVisual(Icons.approval_outlined, Color(0xFFF59E0B));
    case NotificationCategory.servis:
      return CategoryVisual(Icons.build_outlined, Color(0xFF6366F1));
    case NotificationCategory.stok:
      return CategoryVisual(Icons.inventory_2_outlined, Color(0xFF3B82F6));
    case NotificationCategory.produksi:
      return CategoryVisual(
        Icons.precision_manufacturing_outlined,
        Color(0xFFDC2626),
      );
    case NotificationCategory.presensi:
      return CategoryVisual(Icons.fingerprint, Color(0xFF10B981));
    case NotificationCategory.formulir:
      return CategoryVisual(Icons.description_outlined, Color(0xFF059669));
    case NotificationCategory.sistem:
      return CategoryVisual(Icons.campaign_outlined, Color(0xFF64748B));
  }
}

class _SwipeTile extends ConsumerWidget {
  const _SwipeTile({required this.notification, this.onSelected});

  final AppNotification notification;

  /// Return `true` when the callback already handled selection (expanded
  /// master-detail pane). `false` keeps the legacy push/navigation behavior.
  final bool Function(AppNotification)? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final unread = !notification.isRead;
    final visual = categoryVisual(notification.category);
    final resolved = resolveNotificationDestination(
      notification: notification,
      role: ref.watch(activeRoleProvider),
    );
    final body = (notification.body ?? '').trim();
    final destination = _destinationLabel(resolved);
    final subtitle = <String>[
      if (body.isNotEmpty) body,
      ?destination,
    ].join(' • ');

    return Dismissible(
      key: ValueKey(notification.id),
      background: Container(
        color: Colors.red.withValues(alpha: 0.2),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      secondaryBackground: Container(
        color: Colors.green.withValues(alpha: 0.2),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.archive, color: Colors.green),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifikasi ditandai sudah dibaca.')),
          );
        } else if (direction == DismissDirection.endToStart) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifikasi diarsipkan.')),
          );
        }
      },
      child: RichListTile(
        title: notification.title ?? '(Tanpa judul)',
        subtitle: subtitle.isEmpty ? null : subtitle,
        meta: notification.category.label,
        metaColor: visual.color,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (unread ? visual.color : colors.textMuted).withValues(
              alpha: 0.12,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            visual.icon,
            size: 20,
            color: unread ? visual.color : colors.textMuted,
          ),
        ),
        trailing: unread
            ? Semantics(
                label: 'Belum dibaca',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
        onTap: () => _onTap(context, ref, notification),
      ),
    );
  }

  String? _destinationLabel(ResolvedNotificationDestination destination) {
    return switch (destination.status) {
      NotificationTargetStatus.open => 'Buka: ${destination.route}',
      NotificationTargetStatus.openExternal =>
        'Tautan: ${destination.externalUrl}',
      NotificationTargetStatus.deniedRole =>
        'Butuh akses: ${destination.route}',
      NotificationTargetStatus.unavailable => null,
    };
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final error = await ref
        .read(notificationsProvider.notifier)
        .markRead(notification);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (!context.mounted) return;

    final resolved = resolveNotificationDestination(
      notification: notification,
      role: ref.read(activeRoleProvider),
    );

    final handled =
        resolved.status == NotificationTargetStatus.open &&
        onSelected?.call(notification) == true;
    if (handled) return;

    switch (resolved.status) {
      case NotificationTargetStatus.open:
        try {
          context.push(resolved.route!);
        } on StateError {
          messenger.showSnackBar(
            const SnackBar(content: Text('Layar terkait belum tersedia.')),
          );
        }
      case NotificationTargetStatus.openExternal:
        final uri = Uri.tryParse(resolved.externalUrl ?? '');
        if (uri == null) return;
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka tautan.')),
          );
        }
      case NotificationTargetStatus.deniedRole:
      case NotificationTargetStatus.unavailable:
        final message = notificationDestinationMessage(resolved);
        if (message != null) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
    }
  }
}

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DateHeaderDelegate({required this.label});

  final String label;

  @override
  double get minExtent => 32;

  @override
  double get maxExtent => 32;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: context.colors.background,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colors.textTertiary,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

class _NotificationDetail extends ConsumerWidget {
  const _NotificationDetail({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final visual = categoryVisual(notification.category);
    final destination = resolveNotificationDestination(
      notification: notification,
      role: ref.watch(activeRoleProvider),
    );
    final preview = switch (destination.status) {
      NotificationTargetStatus.open => 'Route: ${destination.route}',
      NotificationTargetStatus.openExternal =>
        'Tautan: ${destination.externalUrl}',
      NotificationTargetStatus.deniedRole =>
        'Butuh akses: ${destination.route}',
      NotificationTargetStatus.unavailable => 'Tidak ada tujuan otomatis.',
    };
    final body = notification.body?.trim() ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(visual.icon, color: visual.color),
          ),
          const SizedBox(height: 16),
          Text(
            notification.title ?? '(Tanpa judul)',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${notification.category.label}${notification.time != null ? ' • ${notification.time}' : ''}',
            style: TextStyle(fontSize: 12, color: colors.textTertiary),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tujuan notifikasi',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  preview,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => _openDestination(context, ref, destination),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Buka Tujuan'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDestination(
    BuildContext context,
    WidgetRef ref,
    ResolvedNotificationDestination destination,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(notificationsProvider.notifier).markRead(notification);
    if (!context.mounted) return;
    switch (destination.status) {
      case NotificationTargetStatus.open:
        try {
          context.push(destination.route!);
        } on StateError {
          messenger.showSnackBar(
            const SnackBar(content: Text('Layar terkait belum tersedia.')),
          );
        }
      case NotificationTargetStatus.openExternal:
        final uri = Uri.tryParse(destination.externalUrl ?? '');
        if (uri == null) return;
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Tidak dapat membuka tautan.')),
          );
        }
      case NotificationTargetStatus.deniedRole:
      case NotificationTargetStatus.unavailable:
        final message = notificationDestinationMessage(destination);
        if (message != null) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
    }
  }
}
