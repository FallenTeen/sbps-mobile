import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'version_service.dart';

final versionServiceProvider = Provider<VersionService>(
  (ref) => VersionService(),
);

/// Hasil cek versi saat start.
class VersionGateState {
  const VersionGateState({required this.blocked, this.info});

  final bool blocked;
  final AppVersionInfo? info;

  static const ok = VersionGateState(blocked: false);
}

/// Cek versi saat start (Fase A1.7):
/// force_update=true dan versi terpasang < min_version → layar blocking.
///
/// Gagal jaringan saat cek TIDAK memblokir aplikasi (fail-open) —
/// user tetap bisa bekerja; cek diulang di start berikutnya.
class VersionGateController extends AsyncNotifier<VersionGateState> {
  @override
  Future<VersionGateState> build() async {
    try {
      final info = await ref.read(versionServiceProvider).fetchAppVersion();
      if (!info.forceUpdate || info.minVersion.isEmpty) {
        return VersionGateState.ok;
      }
      final pkg = await PackageInfo.fromPlatform();
      final outdated = _compareVersions(pkg.version, info.minVersion) < 0;
      return VersionGateState(blocked: outdated, info: info);
    } catch (_) {
      return VersionGateState.ok;
    }
  }

  /// -1 bila a < b, 0 sama, 1 a > b. Toleran terhadap "1.2" vs "1.2.0".
  int _compareVersions(String a, String b) {
    List<int> parse(String v) => v
        .split(RegExp(r'[+\-]'))
        .first
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();
    final pa = parse(a), pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }
}

final versionGateProvider =
    AsyncNotifierProvider<VersionGateController, VersionGateState>(
        VersionGateController.new);

/// Layar wajib-update — menutup seluruh aplikasi sampai user update.
class UpdateRequiredScreen extends ConsumerWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final info = ref.watch(versionGateProvider).value?.info;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.system_update_alt,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Versi aplikasi sudah usang',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Silakan perbarui ke versi minimal '
                  '${info?.minVersion ?? '-'} untuk melanjutkan bekerja.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if ((info?.changelog ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(info!.changelog!),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _bukaToko(context, info?.updateUrl ?? ''),
                  icon: const Icon(Icons.download),
                  label: const Text('Perbarui Sekarang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _bukaToko(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Tidak dapat membuka tautan pembaruan.')));
    }
  }
}
