import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../../shared/theme/app_theme.dart';

final shorebirdUpdaterProvider = Provider<ShorebirdUpdater>(
  (ref) => ShorebirdUpdater(),
);

enum ShorebirdUpdatePhase { idle, available, ready }

class ShorebirdUpdateState {
  const ShorebirdUpdateState({this.phase = ShorebirdUpdatePhase.idle, this.busy = false});

  final ShorebirdUpdatePhase phase;
  final bool busy;
}

class ShorebirdUpdateNotifier extends Notifier<ShorebirdUpdateState> {
  @override
  ShorebirdUpdateState build() {
    WidgetsBinding.instance.addPostFrameCallback((_) => recheck());
    return const ShorebirdUpdateState();
  }

  Future<void> recheck() async {
    final updater = ref.read(shorebirdUpdaterProvider);
    if (!updater.isAvailable) return;
    try {
      final status = await updater.checkForUpdate();
      state = switch (status) {
        UpdateStatus.outdated => const ShorebirdUpdateState(phase: ShorebirdUpdatePhase.available),
        UpdateStatus.restartRequired => const ShorebirdUpdateState(phase: ShorebirdUpdatePhase.ready),
        _ => const ShorebirdUpdateState(),
      };
    } catch (_) {
      state = const ShorebirdUpdateState();
    }
  }

  Future<void> download() async {
    if (state.phase != ShorebirdUpdatePhase.available || state.busy) return;
    state = const ShorebirdUpdateState(phase: ShorebirdUpdatePhase.available, busy: true);
    try {
      await ref.read(shorebirdUpdaterProvider).update();
      state = const ShorebirdUpdateState(phase: ShorebirdUpdatePhase.ready);
    } catch (_) {
      state = const ShorebirdUpdateState();
    }
  }
}

final shorebirdUpdateProvider = NotifierProvider<ShorebirdUpdateNotifier, ShorebirdUpdateState>(
  ShorebirdUpdateNotifier.new,
);

/// Banner kontrol update OTA (fase S4.3) — non-blocking, tidak menggate
/// startup. Tampil hanya saat patch tersedia/siap restart.
class ShorebirdUpdateBanner extends ConsumerWidget {
  const ShorebirdUpdateBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shorebirdUpdateProvider);
    final theme = Theme.of(context);
    final primary = context.colors.primary;
    final bg = Color.alphaBlend(
      primary.withValues(alpha: 0.12),
      context.colors.surface,
    );
    final fg =
        bg.computeLuminance() > 0.45
            ? const Color(0xFF1E3A8A)
            : primary;

    return Column(
      children: [
        if (state.phase != ShorebirdUpdatePhase.idle)
          Material(
            color: bg,
            child: SafeArea(
              bottom: false,
              child: InkWell(
                onTap: state.phase == ShorebirdUpdatePhase.available && !state.busy
                    ? () => ref.read(shorebirdUpdateProvider.notifier).download()
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          switch (state.phase) {
                            ShorebirdUpdatePhase.available =>
                              state.busy
                                  ? 'Mengunduh pembaruan…'
                                  : 'Pembaruan tersedia — ketuk untuk unduh.',
                            _ =>
                              'Pembaruan siap — buka ulang aplikasi untuk versi terbaru.',
                          },
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (state.busy)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      else
                        Icon(
                          state.phase == ShorebirdUpdatePhase.available
                              ? Icons.download_rounded
                              : Icons.restart_alt_rounded,
                          size: 16,
                          color: fg,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

