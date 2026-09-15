import 'dart:io';

import 'package:flutter/material.dart';

/// Fullscreen photo viewer with Hero animation, pinch-to-zoom (InteractiveViewer),
/// and quick dismiss gesture / close button.
class PhotoViewerDialog extends StatelessWidget {
  const PhotoViewerDialog({
    super.key,
    required this.heroTag,
    this.imageUrl,
    this.filePath,
    this.title,
  }) : assert(
         imageUrl != null || filePath != null,
         'Must provide either imageUrl or filePath',
       );

  final String heroTag;
  final String? imageUrl;
  final String? filePath;
  final String? title;

  static void show({
    required BuildContext context,
    required String heroTag,
    String? imageUrl,
    String? filePath,
    String? title,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.85),
        pageBuilder: (context, _, _) => PhotoViewerDialog(
          heroTag: heroTag,
          imageUrl: imageUrl,
          filePath: filePath,
          title: title,
        ),
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider imageProvider = filePath != null
        ? FileImage(File(filePath!))
        : NetworkImage(imageUrl!) as ImageProvider;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: title != null
            ? Text(title!, style: const TextStyle(color: Colors.white))
            : null,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Hero(
            tag: heroTag,
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Image(
                image: imageProvider,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Gagal memuat foto',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
