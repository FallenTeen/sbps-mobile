import 'package:flutter/material.dart';

import 'servis_ajuan_form.dart';

/// Bottom sheet Ajuan Servis — body-nya hanyalah [ServisAjuanForm], SAMA
/// dengan full screen (`ajuan_servis_screen.dart`). Tidak ada implementasi
/// form yang berbeda antar kedua entri.
class AjuanServisSheet extends StatelessWidget {
  const AjuanServisSheet({super.key, this.initialArmadaId});

  final String? initialArmadaId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pengajuan Servis',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ServisAjuanForm(
                  initialArmadaId: initialArmadaId,
                  scrollController: scrollController,
                  onSuccess: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Helper untuk membuka sheet ajuan servis konsisten di semua call site.
Future<void> showAjuanServisSheet(
  BuildContext context, {
  String? initialArmadaId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AjuanServisSheet(initialArmadaId: initialArmadaId),
  );
}