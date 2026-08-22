import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'formulir_providers.dart';
import 'models/formulir_lapangan.dart';

/// Riwayat Formulir Lapangan (GET /formulir/riwayat) — pagination
/// "Muat lagi" + thumbnail grid foto.
class RiwayatFormulirScreen extends ConsumerStatefulWidget {
  const RiwayatFormulirScreen({super.key});

  @override
  ConsumerState<RiwayatFormulirScreen> createState() =>
      _RiwayatFormulirScreenState();
}

class _RiwayatFormulirScreenState extends ConsumerState<RiwayatFormulirScreen> {
  final _items = <FormulirLapangan>[];
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
      final res = await ref.read(formulirRepositoryProvider).getRiwayat();
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
      setState(() => _error = 'Gagal memuat riwayat formulir.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(formulirRepositoryProvider).getRiwayat(page: _page + 1);
      setState(() {
        _items.addAll(res.items);
        _page = res.currentPage;
        _lastPage = res.lastPage;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal memuat halaman berikutnya.')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Formulir')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: _error != null && _items.isEmpty
            ? ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(_error!)),
                ),
              ])
            : ListView.builder(
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
                  return _FormulirTile(item: _items[index]);
                },
              ),
      ),
    );
  }
}

class _FormulirTile extends StatelessWidget {
  const _FormulirTile({required this.item});

  final FormulirLapangan item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.tanggal ?? '-',
                      style: theme.textTheme.titleSmall),
                ),
                if ((item.titik ?? '').isNotEmpty)
                  Flexible(
                    child: Text(item.titik!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.aktivitasDilakukan ?? '-',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.foto.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.foto.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.foto[i],
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        color:
                            theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined,
                            size: 20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
