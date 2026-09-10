import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../shared/theme/breakpoints.dart';
import 'tracking_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';
import '../../core/formatters.dart';

/// Daftar user aktif (GPS dalam 1 jam terakhir) — khusus Owner/Admin
/// Keuangan. Auto-refresh tiap 60 detik.
class ActiveUsersScreen extends ConsumerStatefulWidget {
  const ActiveUsersScreen({super.key});

  @override
  ConsumerState<ActiveUsersScreen> createState() => _ActiveUsersScreenState();
}

class _ActiveUsersScreenState extends ConsumerState<ActiveUsersScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(activeUsersProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(activeUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Aktif'),
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(activeUsersProvider.future),
        child: users.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 140),
              Icon(Icons.cloud_off,
                  size: 44, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                e is ApiException ? e.message : 'Gagal memuat user aktif.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton(
                  onPressed: () => ref.invalidate(activeUsersProvider),
                  child: const Text('Coba lagi'),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Icon(Icons.person_search_outlined, size: 44),
                  SizedBox(height: 12),
                  Text(
                    'Tidak ada user dengan GPS dalam 1 jam terakhir.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final isTablet = context.isTablet;
            final crossAxisCount = context.responsiveValue(
              compact: 1,
              medium: 2,
              expanded: 3,
            );

            if (isTablet) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3.0,
                ),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final u = items[i];
                  final last = u.lastSeen?.toLocal();
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(u.nama.isNotEmpty ? u.nama[0] : '?'),
                      ),
                      title: Text(u.nama),
                      subtitle: last == null
                          ? null
                          : Text('Terakhir terlihat '
                              '${fmtRelatif(u.lastSeen)}'),
                      trailing: Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${u.pointCount} titik'),
                      ),
                      onTap: () =>
                          context.push('/tracking/hari-ini/${u.userId}', extra: u.nama),
                    ),
                  );
                },
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final u = items[i];
                final last = u.lastSeen?.toLocal();
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(u.nama.isNotEmpty ? u.nama[0] : '?'),
                    ),
                    title: Text(u.nama),
                    subtitle: last == null
                        ? null
                        : Text('Terakhir terlihat '
                            '${fmtRelatif(u.lastSeen)}'),
                    trailing: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('${u.pointCount} titik'),
                    ),
                    onTap: () =>
                        context.push('/tracking/hari-ini/${u.userId}', extra: u.nama),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
