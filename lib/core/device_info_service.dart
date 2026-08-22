import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Info perangkat untuk header wajib X-Device-Type / X-Device-Name.
///
/// Backend hanya menolak request jika KEDUANYA kosong (hasil audit), tapi
/// keduanya tetap dikirim sebagai praktik baik. Hasil di-cache sekali load.
class DeviceInfoService {
  DeviceInfoService({DeviceInfoPlugin? plugin})
      : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  String? _type;
  String? _name;

  /// 'android' / 'ios' — fallback 'android' di platform lain (dev desktop).
  String get type => _type ?? 'android';

  /// Contoh: "Xiaomi M2012K11AC". Fallback 'unknown' sampai [load] selesai.
  String get name => _name ?? 'unknown';

  Future<void> load() async {
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        _type = 'android';
        _name = '${info.manufacturer} ${info.model}'.trim();
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        _type = 'ios';
        _name = info.utsname.machine;
      }
    } catch (_) {
      // Biarkan fallback type/name default — backend masih menerima request.
    }
  }
}
