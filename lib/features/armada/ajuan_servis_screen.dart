import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/portal_switch_button.dart';
import 'servis_ajuan_form.dart';

/// Form Pengajuan Servis Armada (Section 21 — Bagian 1 Ajuan Driver/PIC).
/// Body-nya hanyalah [ServisAjuanForm] — satu source of truth yang sama
/// dipakai screen maupun bottom sheet.
class AjuanServisScreen extends StatelessWidget {
  const AjuanServisScreen({super.key, this.initialArmadaId});

  final String? initialArmadaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Servis'),
        actions: const [PortalSwitchButton()],
      ),
      body: ServisAjuanForm(
        initialArmadaId: initialArmadaId,
        onSuccess: () => context.pop(),
      ),
    );
  }
}