import 'package:flutter/material.dart';

import 'app_empty_state.dart';

/// State error global — pola "Error State".
///
/// Dipakai saat data gagal dimuat (mis. network error, API down). Menampilkan
/// ikon error besar + pesan + tombol "Coba Lagi". Mengkonsolidasikan pola
/// `_ErrorView` ad-hoc yang sebelumnya di-dup/diisi manual di tiap screen.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.detail,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
  });

  /// Pesan utama error (mis. pesan dari `ApiException`).
  final String message;

  /// Pemicu tombol "Coba Lagi". Jika `null`, tombol tidak ditampilkan.
  final VoidCallback? onRetry;

  /// Detail opsional di bawah pesan (mis. jenis error/kode).
  final String? detail;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: message,
      subtitle: detail,
      actionLabel: onRetry != null ? 'Coba Lagi' : null,
      onAction: onRetry,
      padding: padding,
    );
  }
}