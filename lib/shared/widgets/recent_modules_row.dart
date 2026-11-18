import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_preferences.dart';
import '../../features/proyek/role_permissions.dart';
import 'animations/hero_transition.dart';

class RecentModulesNotifier extends AsyncNotifier<List<String>> {
  static const _maxEntries = 10;

  @override
  Future<List<String>> build() async {
    final raw = await AppPreferences.getString('recent_modules');
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',').where((e) => e.isNotEmpty).toList();
  }

  Future<void> add(String key) async {
    final list = [...(state.value ?? const <String>[])];
    list.remove(key);
    list.insert(0, key);
    if (list.length > _maxEntries) list.length = _maxEntries;
    state = AsyncData(list);
    await AppPreferences.setString('recent_modules', list.join(','));
  }
}

final recentModulesProvider =
    AsyncNotifierProvider<RecentModulesNotifier, List<String>>(
      RecentModulesNotifier.new,
    );

class RecentModulesRow extends ConsumerWidget {
  final int maxItems;
  const RecentModulesRow({super.key, this.maxItems = 3});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentModulesProvider).value ?? const <String>[];
    final modules = recent
        .take(maxItems)
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
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: modules.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final m = modules[i];
          return SizedBox(
            width: 72,
            child: Column(
              children: [
                HeroTransition(
                  tag: 'module-${m.key}',
                  placeholder: CircleAvatar(child: Icon(m.icon, size: 20)),
                  child: CircleAvatar(child: Icon(m.icon, size: 20)),
                ),
                const SizedBox(height: 4),
                Text(
                  m.label,
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
