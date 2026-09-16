import 'package:flutter/material.dart';

import 'app_empty_state.dart';

/// State offline penuh — pola "Offline State".
///
/// Dipakai saat konten membutuhkan koneksi (mis. halaman pemetaan bank soal,
/// halaman yang melarang bekerja offline). Berbeda dari OfflineBanner yang
/// hanya menempel di atas; widget ini menggantikan seluruh area konten.
class OfflineState extends StatelessWidget {
  const OfflineState({
    super.key,
    this.title = 'Mode Offline',
    this.subtitle = 'Periksa koneksi internet lalu coba lagi.',
    this.onRetry,
  });

  final String title;
  final String subtitle;

  /// Pemicu tombol "Coba Lagi". Jika `null`, tombol tidak ditampilkan.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      subtitle: subtitle,
      actionLabel: onRetry != null ? 'Coba Lagi' : null,
      onAction: onRetry,
    );
  }
}