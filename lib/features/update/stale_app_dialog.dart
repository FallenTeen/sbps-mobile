import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../version/version_gate.dart';
import '../version/version_service.dart';
import '../../shared/theme/app_theme.dart';

/// Modal peringatan update besar (versi native usang). Merah, muat di mana
/// saja, tidak mengganggu state layar aktif setelah ditutup.
Future<void> showStaleAppDialog(
  BuildContext context,
  AppVersionInfo? info,
) {
  final version = info?.minVersion;
  final hasLink = info?.updateUrl != null && info!.updateUrl.isNotEmpty;

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final error = dialogContext.colors.error;

      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              error.withValues(alpha: 0.12),
              dialogContext.colors.surface,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: error.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.warning_amber_rounded, size: 44, color: error),
              const SizedBox(height: 12),
              Text(
                'Aplikasi Kadaluwarsa',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Versi aplikasi Anda tidak lagi mendukung layanan saat ini '
                '${version == null || version.isEmpty ? '' : '(minimal $version)'}. '
                'Silakan unduh versi terbaru agar bisa melanjutkan seperti biasa.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: error,
                  foregroundColor:
                      error.computeLuminance() > 0.45
                          ? Colors.black
                          : Colors.white,
                ),
                onPressed: hasLink
                    ? () async {
                        final uri = Uri.tryParse(info.updateUrl);
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    : null,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Unduh Aplikasi'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Nanti'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Listener update besar: tampilkan modal [showStaleAppDialog] saat app
/// kadaluwarsa, sekali per entri layar. Wrap [LoginScreen] dan layar portal.
class StaleAppGate extends ConsumerStatefulWidget {
  const StaleAppGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StaleAppGate> createState() => _StaleAppGateState();
}

class _StaleAppGateState extends ConsumerState<StaleAppGate> {
  bool _shown = false;

  void _maybeShow(AsyncValue<VersionGateState> gate) {
    final blocked = gate.value?.blocked ?? false;
    if (!blocked || _shown || !mounted) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showStaleAppDialog(context, gate.value?.info);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _maybeShow(ref.read(versionGateProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(versionGateProvider, (_, next) => _maybeShow(next));
    return widget.child;
  }
}
