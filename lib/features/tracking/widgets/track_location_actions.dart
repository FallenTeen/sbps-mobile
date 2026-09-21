import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet aksi lokasi titip untuk layar Tracking:
///
///  1. **Buka di Google Maps** — buka [url] di aplikasi Google Maps eksternal
///     (fallback browser). URL memakai format universal (tidak butuh Google
///     Maps SDK / API key) dan selalu dari server bila tersedia.
///  2. **Bagikan Lokasi** — salin [url] ke clipboard + munculkan snackbar
///     (tanpa dependensi share_plus, sesuai keputusan).
///
/// [url] HARUS sudah dipastikan ada oleh pemanggil (lihat resolveLocationUrl
/// di tracking_rules.dart). [nama] untuk label orang yang titiknya dibagikan.
Future<void> showTrackLocationActions(
  BuildContext context, {
  required String url,
  required String nama,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Lokasi GPS terakhir',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('Buka di Google Maps'),
            subtitle: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _openInGoogleMaps(context, url),
          ),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: const Text('Bagikan Lokasi'),
            subtitle: const Text('Salin tautan Google Maps'),
            onTap: () => _copyToClipboard(context, url, nama),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _openInGoogleMaps(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  Navigator.of(context).pop();

  final uri = Uri.tryParse(url);
  if (uri == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('URL lokasi tidak valid.')),
    );
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Tidak dapat membuka Google Maps.')),
    );
  }
}

Future<void> _copyToClipboard(
  BuildContext context,
  String url,
  String nama,
) async {
  final messenger = ScaffoldMessenger.of(context);
  Navigator.of(context).pop();

  await Clipboard.setData(ClipboardData(text: url));
  messenger.showSnackBar(
    SnackBar(content: Text('Tautan lokasi $nama disalin.')),
  );
}