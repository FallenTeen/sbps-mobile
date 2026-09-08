import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/breakpoints.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/entrance_fader.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../core/api_client.dart';
import 'models/presensi_hari_ini.dart';
import 'presensi_providers.dart';

const _bulanNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Riwayat presensi (GET /presensi/riwayat) — filter bulan/tahun,
/// pagination tombol "Muat lagi".
class RiwayatScreen extends ConsumerStatefulWidget {
  const RiwayatScreen({super.key});

  @override
  ConsumerState<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends ConsumerState<RiwayatScreen> {
  late int _bulan = DateTime.now().month;
  late int _tahun = DateTime.now().year;

  final _items = <RiwayatPresensi>[];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final res = await ref.read(presensiRepositoryProvider).getRiwayat(
            bulan: _bulan,
            tahun: _tahun,
          );
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _lastPage = res.lastPage;
        _page = res.currentPage;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Gagal memuat riwayat.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    setState(() => _loading = true);
    try {
      final res = await ref.read(presensiRepositoryProvider).getRiwayat(
            bulan: _bulan,
            tahun: _tahun,
            page: _page + 1,
          );
      setState(() {
        _items.addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat halaman berikutnya.')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Presensi')),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _bulan,
                      decoration: const InputDecoration(labelText: 'Bulan'),
                      items: [
                        for (var i = 1; i <= 12; i++)
                          DropdownMenuItem(value: i, child: Text(_bulanNames[i - 1])),
                      ],
                      onChanged: (v) {
                        if (v != null && v != _bulan) {
                          setState(() => _bulan = v);
                          _reload();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _tahun,
                      decoration: const InputDecoration(labelText: 'Tahun'),
                      items: [
                        for (var y = now.year; y >= now.year - 5; y--)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (v) {
                        if (v != null && v != _tahun) {
                          setState(() => _tahun = v);
                          _reload();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty && _error == null) {
      return const SkeletonListView(itemCount: 6);
    }

    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Gagal Memuat Riwayat',
            subtitle: _error,
            actionLabel: 'Coba Lagi',
            onAction: _reload,
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          AppEmptyState(
            icon: Icons.history_toggle_off,
            title: 'Belum Ada Riwayat',
            subtitle: 'Tidak ada data presensi pada bulan dan tahun ini.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_page < _lastPage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : FilledButton.tonal(
                      onPressed: _loadMore,
                      child: const Text('Muat lagi'),
                    ),
            ),
          );
        }
        return StaggeredEntrance(
          index: index,
          child: _RiwayatTile(item: _items[index]),
        );
      },
    );
  }
}

class _RiwayatTile extends StatelessWidget {
  const _RiwayatTile({required this.item});

  final RiwayatPresensi item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final luarRadius = item.statusValidasi == 'luar_radius';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          luarRadius ? Icons.warning_amber_outlined : Icons.check_circle_outline,
          color: luarRadius
              ? theme.colorScheme.error
              : theme.colorScheme.primary,
        ),
        title: Text(item.tanggal ?? '-'),
        subtitle: Text(
          '${item.namaTitik ?? 'Titik'} • '
          'Masuk ${_jam(item.checkIn)} • Pulang ${_jam(item.checkOut)}',
        ),
        trailing: Text(_statusLabel(item.status), style: theme.textTheme.bodySmall),
      ),
    );
  }

  String _jam(String? iso) {
    final t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '-';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _statusLabel(String? status) => switch (status) {
        'menunggu_check_out' => 'Berlangsung',
        'selesai' => 'Selesai',
        'belum_check_in' => 'Belum check-in',
        _ => status ?? '-',
      };
}
