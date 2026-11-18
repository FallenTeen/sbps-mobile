import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_preferences.dart';
import '../../features/proyek/role_permissions.dart';
import '../utils/feedback_service.dart';
import '../utils/module_routes.dart';
import 'module_shortcut.dart';
import 'recent_modules_row.dart' show recentModulesProvider;

class PinnedModulesRow extends ConsumerStatefulWidget {
  final int maxItems;
  const PinnedModulesRow({super.key, this.maxItems = 4});

  @override
  ConsumerState<PinnedModulesRow> createState() => _PinnedModulesRowState();
}

class _PinnedModulesRowState extends ConsumerState<PinnedModulesRow> {
  List<String> _pinned = const [];

  static const _defaults = ['dashboard', 'produksi', 'armada', 'logistik'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await AppPreferences.getString('pinned_modules');
    final list = raw == null || raw.isEmpty
        ? [..._defaults]
        : raw.split(',').where((e) => e.isNotEmpty).toList();
    if (!mounted) return;
    setState(() => _pinned = list);
  }

  Future<void> _save() =>
      AppPreferences.setString('pinned_modules', _pinned.join(','));

  Future<void> _togglePin(String key) async {
    setState(() {
      if (_pinned.contains(key)) {
        _pinned = [..._pinned]..remove(key);
      } else {
        _pinned = [key, ..._pinned];
      }
    });
    await _save();
    if (mounted) {
      FeedbackService.info(
        context,
        _pinned.contains(key) ? 'Modul dipin' : 'Pin modul dihapus',
      );
    }
  }

  void _openModule(String key) {
    final route = moduleRouteFor(key);
    if (route == null) return;
    ref.read(recentModulesProvider.notifier).add(key);
    context.push(route);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModuleSectionLabel(
          label: 'Akses Cepat',
          icon: Icons.push_pin_outlined,
        ),
        SizedBox(
          height: 84,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Dual SDK support: onReorderItem only exists in newer Flutter.
            // ignore: deprecated_member_use
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
                Padding(
                  key: ValueKey(modules[i].key),
                  padding: const EdgeInsets.only(right: 8),
                  child: ModuleShortcut(
                    icon: modules[i].icon,
                    label: modules[i].label,
                    onTap: () => _openModule(modules[i].key),
                    onLongPress: () => _togglePin(modules[i].key),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
