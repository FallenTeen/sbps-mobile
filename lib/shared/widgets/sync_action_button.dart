import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/presensi/presensi_providers.dart';
import 'animated_badge.dart';

/// Connectivity status: online / offline / checking.
enum ConnectivityStatus { online, offline, checking }

/// Provider yang memantau status konektivitas perangkat.
final connectivityStatusProvider =
    StreamProvider.autoDispose<ConnectivityStatus>((ref) async* {
      final stream = Connectivity().onConnectivityChanged;
      await for (final results in stream) {
        final online = results.any((r) => r != ConnectivityResult.none);
        yield online ? ConnectivityStatus.online : ConnectivityStatus.offline;
      }
    });

/// Tombol sinkron global — bisa ditaruh di AppBar layar manapun.
///
/// Menampilkan ikon cloud + badge jumlah aksi tertunda + dot berkedip.
/// Tap → force sync semua aksi outbox, tampilkan snackbar hasilnya.
class SyncActionButton extends ConsumerWidget {
  const SyncActionButton({super.key, this.compact = false});

  /// Mode compact: badge lebih kecil, cocok untuk AppBar sempit.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingCountProvider);

    return Semantics(
      button: true,
      label: count > 0
          ? 'Sinkronisasi outbox. $count aksi menunggu dikirim'
          : 'Sinkronisasi outbox. Semua data tersimpan aman',
      child: IconButton(
        tooltip: count > 0
            ? '$count aksi menunggu sinkronisasi'
            : 'Semua data sudah tersinkron',
        icon: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedCountBadge(
              count: count,
              badgeColor: Colors.orange.shade700,
              child: Icon(
                count > 0
                    ? Icons.cloud_upload_outlined
                    : Icons.cloud_done_outlined,
                size: compact ? 22 : 24,
              ),
            ),
            if (count > 0)
              Positioned(
                top: 2,
                right: compact ? 0 : 2,
                child: const PulsingSyncDot(size: 6),
              ),
          ],
        ),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final sync = ref.read(outboxSyncServiceProvider);
          await sync.syncNow(ignoreBackoff: true);
          final remaining = ref.read(pendingCountProvider);
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                remaining > 0
                    ? 'Sinkronisasi selesai — $remaining aksi masih tertunda.'
                    : 'Semua data berhasil disinkronkan.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onLongPress: () => context.push('/data-belum-terkirim'),
      ),
    );
  }
}

/// Banner global yang menjelaskan bahwa aplikasi tetap menyimpan data saat offline.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityStatusProvider);
    final offline =
        status.whenOrNull(
          data: (value) => value == ConnectivityStatus.offline,
        ) ??
        false;
    return Column(
      children: [
        if (offline)
          Material(
            color: const Color(0xFFFEF3C7),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Anda sedang offline — data tetap tersimpan di HP.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF92400E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
