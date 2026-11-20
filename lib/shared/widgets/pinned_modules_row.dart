import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_preferences.dart';
import '../../features/proyek/role_permissions.dart';
import '../utils/feedback_service.dart';
import '../utils/module_routes.dart';
import 'module_shortcut.dart';

List<String> visiblePinnedModules(
  List<String> pinned,
  Set<String> allowedModules,
) => pinned.where((key) => allowedModules.contains(key)).toList();

class PinnedModulesRow extends ConsumerStatefulWidget {
  final Set<String> allowedModules;
  final int maxItems;
  const PinnedModulesRow({
    super.key,
    required this.allowedModules,
    this.maxItems = 4,
  });

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
    if (!widget.allowedModules.contains(key)) return;
    final route = moduleRouteFor(key);
    if (route == null) return;
    context.push(route);
  }

  void _reorderPinned(int oldIndex, int newIndex) {
    final allowed = widget.allowedModules;
    final displayed = visiblePinnedModules(_pinned, allowed)
        .take(widget.maxItems)
        .toList();
    if (oldIndex < 0 || oldIndex >= displayed.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    if (target < 0 || target >= displayed.length) return;

    displayed.insert(target, displayed.removeAt(oldIndex));
    var next = 0;
    final reordered = [
      for (final key in _pinned)
        allowed.contains(key) && next < displayed.length
            ? displayed[next++]
            : key,
    ];
    setState(() => _pinned = reordered);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final modules = visiblePinnedModules(_pinned, widget.allowedModules)
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
            onReorder: _reorderPinned,
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
