import 'package:flutter/material.dart';

import '../../core/app_preferences.dart';

class GlobalSearchSheet extends StatefulWidget {
  final List<SearchableModule> modules;
  final ValueChanged<SearchResult> onSelected;
  const GlobalSearchSheet({super.key, required this.modules, required this.onSelected});

  @override
  State<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<GlobalSearchSheet> {
  static const _kRecentKey = 'global_search_recent';
  static const _kMaxRecent = 5;

  final _ctrl = TextEditingController();
  String _q = '';
  List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final raw = await AppPreferences.getString(_kRecentKey);
      if (raw == null || raw.isEmpty) return;
      if (!mounted) return;
      setState(() => _recent = raw.split(',').where((e) => e.isNotEmpty).toList());
    } catch (_) {}
  }

  Future<void> _remember(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final next = [q, ..._recent.where((e) => e.toLowerCase() != q.toLowerCase())];
    if (next.length > _kMaxRecent) next.removeRange(_kMaxRecent, next.length);
    setState(() => _recent = next);
    try {
      await AppPreferences.setString(_kRecentKey, next.join(','));
    } catch (_) {}
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = []);
    try {
      await AppPreferences.setString(_kRecentKey, '');
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<SearchResult> get _results {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final out = <SearchResult>[];
    for (final m in widget.modules) {
      for (final r in m.items) {
        if (r.title.toLowerCase().contains(q) || r.subtitle.toLowerCase().contains(q)) {
          out.add(r);
        }
      }
    }
    return out;
  }

  void _select(SearchResult r) {
    _remember(_q.trim().isEmpty ? r.title : _q);
    Navigator.of(context).pop();
    widget.onSelected(r);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cari modul...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
              onSubmitted: _remember,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: _q.trim().isEmpty
                  ? _buildRecent(context)
                  : (results.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('Tidak ada hasil'),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final r = results[i];
                            return ListTile(
                              leading: Icon(r.icon),
                              title: Text(r.title),
                              subtitle: Text(r.subtitle),
                              onTap: () => _select(r),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecent(BuildContext context) {
    if (_recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Ketik untuk mencari modul'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pencarian terakhir', style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            TextButton(onPressed: _clearRecent, child: const Text('Hapus')),
          ],
        ),
        ..._recent.map(
          (q) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(q),
            onTap: () {
              _ctrl.text = q;
              setState(() => _q = q);
            },
          ),
        ),
      ],
    );
  }
}

class SearchableModule {
  final String name;
  final List<SearchResult> items;
  const SearchableModule({required this.name, required this.items});
}

class SearchResult {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  const SearchResult({required this.title, required this.subtitle, required this.icon, required this.route});
}

Future<void> showGlobalSearchSheet(
  BuildContext context, {
  required List<SearchableModule> modules,
  required ValueChanged<SearchResult> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => GlobalSearchSheet(modules: modules, onSelected: onSelected),
  );
}