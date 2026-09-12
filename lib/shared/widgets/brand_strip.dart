import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Strip gradien identitas SBPS (Fase C5) untuk diletakkan di `bottom`
/// AppBar modul utama. Memberi "kain merah" tipis pada header modul agar
/// identitas visual konsisten dengan header gradien ringkasan.
class BrandStrip extends StatelessWidget implements PreferredSizeWidget {
  const BrandStrip({super.key, this.height = 3});

  final double height;

  @override
  Size get preferredSize => Size(double.infinity, height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
    );
  }
}