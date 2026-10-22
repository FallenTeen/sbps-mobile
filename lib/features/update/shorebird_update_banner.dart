import 'dart:async';
import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../tracking/background_location_service.dart';
import '../version/version_gate.dart';
import '../../shared/theme/app_theme.dart';

final shorebirdUpdaterProvider = Provider<ShorebirdUpdater>(
  (ref) => ShorebirdUpdater(),
);

enum ShorebirdUpdatePhase { idle, downloading, ready }

class ShorebirdUpdateState {
  const ShorebirdUpdateState({this.phase = ShorebirdUpdatePhase.idle, this.promptShown = false});

  final ShorebirdUpdatePhase phase;
  final bool promptShown;
}

/// Kontroler update OTA (fase S4.3): cek patch di background, unduh otomatis
/// saat ada patch baru, dan prompt restart hanya SETELAH unduhan berhasil.
/// Prompt 1x per sesi — tidak menggate startup.
class ShorebirdUpdateNotifier extends Notifier<ShorebirdUpdateState> {
  @override
  ShorebirdUpdateState build() {
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
    return const ShorebirdUpdateState();
  }

  Future<void> refresh() async {
    final updater = ref.read(shorebirdUpdaterProvider);
    if (!updater.isAvailable) return;
    try {
      final status = await updater.checkForUpdate();
      switch (status) {
        case UpdateStatus.outdated:
          if (state.phase == ShorebirdUpdatePhase.downloading) return;
          state = const ShorebirdUpdateState(phase: ShorebirdUpdatePhase.downloading);
          try {
            await updater.update();
            state = ShorebirdUpdateState(
              phase: ShorebirdUpdatePhase.ready,
              promptShown: state.promptShown,
            );
          } catch (_) {
            state = ShorebirdUpdateState(
              phase: ShorebirdUpdatePhase.idle,
              promptShown: state.promptShown,
            );
          }
        case UpdateStatus.restartRequired:
          if (state.phase != ShorebirdUpdatePhase.ready) {
            state = ShorebirdUpdateState(
              phase: ShorebirdUpdatePhase.ready,
              promptShown: state.promptShown,
            );
          }
        case UpdateStatus.upToDate:
        case UpdateStatus.unavailable:
          if (state.phase == ShorebirdUpdatePhase.downloading) return;
          state = ShorebirdUpdateState(
            phase: ShorebirdUpdatePhase.idle,
            promptShown: state.promptShown,
          );
      }
    } catch (_) {
      if (state.phase != ShorebirdUpdatePhase.downloading) {
        state = ShorebirdUpdateState(
          phase: ShorebirdUpdatePhase.idle,
          promptShown: state.promptShown,
        );
      }
    }
  }

  void markPromptShown() {
    if (!state.promptShown) {
      state = ShorebirdUpdateState(
        phase: state.phase,
        promptShown: true,
      );
    }
  }
}

final shorebirdUpdateProvider =
    NotifierProvider<ShorebirdUpdateNotifier, ShorebirdUpdateState>(
      ShorebirdUpdateNotifier.new,
    );

/// Host popup pembaharuan OTA — full-screen overlay di atas aplikasi.
/// Muncul 1x per sesi saat patch siap, tanpa mengganggu state layar aktif.
class ShorebirdUpdateBanner extends ConsumerWidget {
  const ShorebirdUpdateBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shorebirdUpdateProvider);
    final show = state.phase == ShorebirdUpdatePhase.ready && !state.promptShown;

    return Stack(
      children: [
        Positioned.fill(child: child),
        if (show) Positioned.fill(child: const _UpdatePrompt()),
      ],
    );
  }
}

class _UpdatePrompt extends ConsumerStatefulWidget {
  const _UpdatePrompt();

  @override
  ConsumerState<_UpdatePrompt> createState() => _UpdatePromptState();
}

class _UpdatePromptState extends ConsumerState<_UpdatePrompt> {
  static const _minShow = Duration(seconds: 3);
  Timer? _timer;
  int _remaining = _minShow.inSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (t.tick >= _minShow.inSeconds) {
        t.cancel();
        if (mounted) setState(() => _remaining = 0);
        return;
      }
      if (mounted) setState(() => _remaining = _minShow.inSeconds - t.tick);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = context.colors.warning;
    final changelog = ref.watch(versionGateProvider).value?.info?.changelog;

    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                warning.withValues(alpha: 0.14),
                context.colors.surface,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: warning.withValues(alpha: 0.45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.new_releases_outlined, size: 44, color: warning),
                const SizedBox(height: 12),
                Text(
                  'Pembaruan telah terpasang',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Buka ulang aplikasi agar pembaruan terbaru aktif.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if ((changelog ?? '').isNotEmpty)
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        'Daftar perubahan',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(changelog!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _remaining > 0 ? null : _tutup,
                        child: Text(
                          _remaining > 0 ? 'Tutup dalam $_remaining…' : 'Nanti',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: warning,
                          foregroundColor:
                              warning.computeLuminance() > 0.45
                                  ? Colors.black
                                  : Colors.white,
                        ),
                        onPressed:
                            _remaining > 0 ? null : _bukaUlangSekarang,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Buka ulang'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _tutup() {
    ref.read(shorebirdUpdateProvider.notifier).markPromptShown();
  }

  /// Hentikan background tracking (notifikasi ikut hilang via
  /// `service.stopSelf()`) lalu matikan proses — syarat patch aktif.
  Future<void> _bukaUlangSekarang() async {
    try {
      final tracking = BackgroundLocationService.instance;
      if (await tracking.isRunning()) {
        await tracking.stopTracking();
      }
    } catch (_) {
      // Gagal stop service tetap lanjut matikan proses.
    }
    await SystemNavigator.pop();
    exit(0);
  }
}
