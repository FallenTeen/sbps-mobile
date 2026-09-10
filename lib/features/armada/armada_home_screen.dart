import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/portal_switch_button.dart';
import 'armada_providers.dart';
import 'driver_dashboard_screen.dart';
import 'models/armada.dart';

class ArmadaHomeScreen extends ConsumerWidget {
  const ArmadaHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: null,
        actions: const [PortalSwitchButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(armadaSayaProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.local_shipping_rounded,
                      color: Colors.white, size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Armada',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kendaraan & operasional harian',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Kendaraan Saya section
            Row(
              children: [
                Icon(Icons.directions_bus_rounded,
                    size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Kendaraan Saya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._armadaSection(ref),
            const SizedBox(height: 24),

            // Menu section
            Row(
              children: [
                Icon(Icons.apps_rounded,
                    size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Menu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MenuTile(
              icon: Icons.dashboard_outlined,
              title: 'Dashboard Saya',
              subtitle: 'Ringkasan kinerja & ritase hari ini',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const DriverDashboardScreen()),
              ),
            ),
            _MenuTile(
              icon: Icons.route_outlined,
              title: 'Riwayat Ritase',
              subtitle: 'Pengiriman & upah per rit',
              onTap: () => context.push('/armada/ritase'),
            ),
            _MenuTile(
              icon: Icons.checklist_rtl,
              title: 'Checklist Harian',
              subtitle: 'Catat kondisi kendaraan hari ini',
              onTap: () => context.push('/armada/checklist'),
            ),
            _MenuTile(
              icon: Icons.badge_outlined,
              title: 'Presensi Helper',
              subtitle: 'Absenkan helper armada hari ini',
              onTap: () => context.push('/armada/helper-presensi'),
            ),
            _MenuTile(
              icon: Icons.speed_outlined,
              title: 'ODO Awal Proyek',
              subtitle: 'Catat ODO awal kendaraan per ritase',
              onTap: () => context.push('/armada/odo-awal'),
            ),
            _MenuTile(
              icon: Icons.build_outlined,
              title: 'Servis Armada',
              subtitle: 'Pengajuan & riwayat perbaikan armada',
              onTap: () => context.push('/armada/servis'),
            ),
            _MenuTile(
              icon: Icons.edit_road_outlined,
              title: 'Input Ritase',
              subtitle: 'Catat jumlah rit & satuan hari ini',
              onTap: () => context.push('/armada/ritase-input'),
            ),
            _MenuTile(
              icon: Icons.engineering_outlined,
              title: 'Workshop To-Do',
              subtitle: 'Daftar tugas perbaikan harian',
              onTap: () => context.push('/armada/workshop-todo'),
            ),
            _MenuTile(
              icon: Icons.assignment_outlined,
              title: 'Checklist Major',
              subtitle: 'Serah terima kondisi kendaraan',
              onTap: () => context.push('/armada/checklist-major'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _armadaSection(WidgetRef ref) {
    final armada = ref.watch(armadaSayaProvider);
    return switch (armada) {
      AsyncData(value: final items) => items.isEmpty
          ? const [_EmptyArmada()]
          : [for (final a in items) _ArmadaCard(armada: a)],
      AsyncError(:final error) => [_ErrorView(message: '$error')],
      _ => const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
    };
  }
}

// ── Menu Tile ─────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Armada Card ───────────────────────────────────────────────────────────────

class _ArmadaCard extends StatelessWidget {
  const _ArmadaCard({required this.armada});

  final ArmadaSaya armada;

  @override
  Widget build(BuildContext context) {
    final aktif = armada.status == 'aktif' || armada.status == 'beroperasi';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  armada.platNomor,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: aktif
                      ? AppTheme.successColor.withValues(alpha: 0.1)
                      : AppTheme.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  armada.status ?? '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: aktif ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (armada.jenis != null)
                _InfoChip(label: 'Jenis', value: _labelJenis(armada.jenis!)),
              if (armada.kodeUnit != null)
                _InfoChip(label: 'Unit', value: armada.kodeUnit!),
              if (armada.titikNama != null)
                _InfoChip(label: 'Titik', value: armada.titikNama!),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariantColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyArmada extends StatelessWidget {
  const _EmptyArmada();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: const Column(
        children: [
          Icon(Icons.no_crash_outlined, size: 40, color: AppTheme.textMuted),
          SizedBox(height: 10),
          Text(
            'Belum ada armada yang ditugaskan ke Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

String _labelJenis(String jenis) => switch (jenis) {
      'dump_truck' => 'Dump Truck',
      'mixer_beton' => 'Mixer Beton',
      'excavator' => 'Excavator',
      'mobil_pickup' => 'Mobil Pickup',
      _ => jenis,
    };
