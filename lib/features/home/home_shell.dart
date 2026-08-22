import 'package:flutter/material.dart';

import '../../core/app_config.dart';

/// Judul app bar sesuai flavor aktif (presensi / proyek).
class HomeTitle extends StatelessWidget {
  const HomeTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final title = AppConfig.appFlavor == 'proyek'
        ? 'SBPS Proyek'
        : 'SBPS Presensi';
    return Text(title);
  }
}
