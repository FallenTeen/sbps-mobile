import 'package:flutter/material.dart';

class GlobalSearchSheet extends StatefulWidget {
  final List<SearchableModule> modules;
  final ValueChanged<SearchResult> onSelected;
  const GlobalSearchSheet({super.key, required this.modules, required this.onSelected});

  @override
  State<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<GlobalSearchSheet> {
  final _ctrl = TextEditingController();
  String _q = '';

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

  @override
  Widget build(BuildContext context) {
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
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return ListTile(
                    leading: Icon(r.icon),
                    title: Text(r.title),
                    subtitle: Text(r.subtitle),
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSelected(r);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
