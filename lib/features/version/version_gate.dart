import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
      final info = await ref
          .read(versionServiceProvider)
          .fetchAppVersion('mobile');
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
      VersionGateController.new,
    );

