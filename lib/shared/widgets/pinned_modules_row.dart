import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_preferences.dart';
import '../../features/proyek/role_permissions.dart';
import 'animations/hero_transition.dart';

class PinnedModulesRow extends ConsumerStatefulWidget {
  final int maxItems;
  const PinnedModulesRow({super.key, this.maxItems = 4});

  @override
  ConsumerState<PinnedModulesRow> createState() => _PinnedModulesRowState();
}

class _PinnedModulesRowState extends ConsumerState<PinnedModulesRow> {
  List<String> _pinned = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await AppPreferences.getString('pinned_modules');
    if (raw == null || raw.isEmpty) return;
    if (mounted) {
      setState(
        () => _pinned = raw.split(',').where((e) => e.isNotEmpty).toList(),
      );
    }
  }

  Future<void> _save() async {
    await AppPreferences.setString('pinned_modules', _pinned.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final modules = _pinned
        .take(widget.maxItems)
        .map(
          (key) => kProyekModules.firstWhere(
            (m) => m.key == key,
            orElse: () => ProyekModule(key: key, label: key, icon: Icons.apps),
          ),
        )
        .toList();

    if (modules.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 80,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _pinned.removeAt(oldIndex);
            _pinned.insert(newIndex, item);
          });
          _save();
        },
        children: [
          for (int i = 0; i < modules.length; i++)
            SizedBox(
              key: ValueKey(modules[i].key),
              width: 72,
              child: Column(
                children: [
                  HeroTransition(
                    tag: 'module-${modules[i].key}',
                    placeholder: CircleAvatar(
                      child: Icon(modules[i].icon, size: 20),
                    ),
                    child: CircleAvatar(child: Icon(modules[i].icon, size: 20)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modules[i].label,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
