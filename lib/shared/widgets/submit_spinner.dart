import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Spinner kecil untuk tombol submit yang sengaja di-disable selama
/// proses berjalan (fill abu M3).
///
/// Memakai [disabledForeground] (onSurface α38% — sama dengan disabled
/// foreground bawaan Material) supaya spinner tetap terbaca di mode terang
/// maupun gelap, menggantikan pola `color: Colors.white` yang tak terlihat
/// di atas fill abu.
class SubmitSpinner extends StatelessWidget {
  const SubmitSpinner({super.key, this.size = 20, this.strokeWidth = 2});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: disabledForeground(context),
      ),
    );
  }
}