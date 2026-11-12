import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_top_bar_actions.dart';
import '../../shared/widgets/brand_strip.dart';
import 'security_repository.dart';

/// Modul /security Home Shell (Section 27, TD-F1).
///
/// Menampilkan pintasan utama:
/// 1. Buku Tamu (TD-F2)
/// 2. Checklist Pemantauan Kantor (TD-F3)
/// 3. Laporan Darurat (TD-F4)
/// 4. Verifikasi Ritase (TD-E4 & TD-F5)
class SecurityHomeScreen extends ConsumerWidget {
  const SecurityHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bukuTamuAsync = ref.watch(bukuTamuHariIniProvider);
    final ritaseAsync = ref.watch(ritaseSecurityAntreanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security & Keamanan'),
        bottom: const BrandStrip(),
        actions: const [AppTopBarActions()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bukuTamuHariIniProvider);
          ref.invalidate(ritaseSecurityAntreanProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            // Status Ringkasan Hari Ini
            Card(
              elevation: 0,
              color: context.colors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: context.colors.primary.withValues(alpha: 0.25)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: context.colors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Pos Keamanan Aktif',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: bukuTamuAsync.when(
                            loading: () => const Text('Memuat tamu...'),
                            error: (error, stack) => const Text('Tamu: -'),
                            data: (list) {
                              final aktif = list.where((t) => !t.isSudahKeluar).length;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$aktif',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                  Text(
                                    'Tamu di Lokasi',
                                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Container(height: 36, width: 1, color: context.colors.border),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ritaseAsync.when(
                            loading: () => const Text('Memuat ritase...'),
                            error: (error, stack) => const Text('Ritase: -'),
                            data: (list) {
                              final butuh = list.where((r) => !r.isVerifiedSecurity).length;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$butuh',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.success,
                                    ),
                                  ),
                                  Text(
                                    'Ritase Siap Cek',
                                    style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Pintasan Utama (TD-F1)
            Text(
              'Menu Operasional Security',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // 1. Buku Tamu (TD-F2)
            _SecurityMenuTile(
              title: 'Buku Tamu',
              subtitle: 'Catat tamu masuk, plat kendaraan & tandai keluar',
              icon: Icons.menu_book_rounded,
              color: context.colors.info,
              onTap: () => context.push('/security/buku-tamu'),
            ),
            const SizedBox(height: 10),

            // 2. Checklist Pemantauan Kantor (TD-F3)
            _SecurityMenuTile(
              title: 'Checklist Pemantauan Kantor',
              subtitle: 'Patroli & checklist keamanan fasilitas (siang / malam)',
              icon: Icons.checklist_rounded,
              color: context.colors.secondary,
              onTap: () => context.push('/security/checklist'),
            ),
            const SizedBox(height: 10),

            // 3. Laporan Darurat (TD-F4)
            _SecurityMenuTile(
              title: 'Laporan Darurat',
              subtitle: 'Lapor cepat insiden/bahaya ke Owner & Pimpinan',
              icon: Icons.warning_rounded,
              color: context.colors.error,
              badgeText: 'PENTING',
              badgeColor: context.colors.error,
              onTap: () => context.push('/security/darurat/baru'),
            ),
            const SizedBox(height: 10),

            // 4. Verifikasi Ritase (TD-E4 & TD-F5)
            _SecurityMenuTile(
              title: 'Verifikasi Keamanan Ritase',
              subtitle: 'Konfirmasi unit & fisik muatan armada yang verified logistik',
              icon: Icons.local_shipping_outlined,
              color: context.colors.success,
              onTap: () => context.push('/security/verifikasi-ritase'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityMenuTile extends StatelessWidget {
  const _SecurityMenuTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: badgeColor ?? color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
