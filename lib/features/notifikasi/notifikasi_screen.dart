import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/theme/breakpoints.dart';
import '../../shared/utils/date_grouping.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/notification_routes.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../shared/widgets/rich_list_tile.dart';
import '../../shared/widgets/searchable_list_header.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../auth/auth_providers.dart';
import 'models/notification.dart';
import 'notifikasi_providers.dart';

/// Pusat notifikasi (Phase 16 action center): filter kategori
/// (Approval/Servis/Stok/Produksi/Presensi/Formulir/Sistem), status baca,
/// dan tap → markRead lalu navigasi deep-link ke layar terkait. Destination
/// yang tidak dikenali / tanpa hak akses tetap dibuka secara jelas (pesan
/// snackbar) — bukan diam.
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

    final filtered = searched.where((n) => _category == null || n.category == _category);
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
    final rows = _buildRows(visible);

    return Column(
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
  // Dipanggil dalam build — warna mengikuti tema via context.
  switch (c) {
    case NotificationCategory.approval:
      return CategoryVisual(
        Icons.approval_outlined,
        Color(0xFFF59E0B),
      );
    case NotificationCategory.servis:
      return CategoryVisual(Icons.build_outlined, Color(0xFF6366F1));
    case NotificationCategory.stok:
      return CategoryVisual(
        Icons.inventory_2_outlined,
        Color(0xFF3B82F6),
      );
    case NotificationCategory.produksi:
      return CategoryVisual(
        Icons.precision_manufacturing_outlined,
        Color(0xFFDC2626),
      );
    case NotificationCategory.presensi:
      return CategoryVisual(Icons.fingerprint, Color(0xFF10B981));
    case NotificationCategory.formulir:
      return CategoryVisual(
        Icons.description_outlined,
        Color(0xFF059669),
      );
    case NotificationCategory.sistem:
      return CategoryVisual(Icons.campaign_outlined, Color(0xFF64748B));
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
    final visual = categoryVisual(notification.category);

    return RichListTile(
      title: notification.title ?? '(Tanpa judul)',
      subtitle: (notification.body ?? '').isNotEmpty ? notification.body : null,
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
    if (!context.mounted) return;

    final resolved = resolveNotificationDestination(
      notification: notification,
      role: ref.read(activeRoleProvider),
    );

    switch (resolved.status) {
      case NotificationTargetStatus.open:
        // Deep-link internal: push (bukan go) supaya back stack tetap utuh —
        // user bisa kembali ke daftar notifikasi.
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