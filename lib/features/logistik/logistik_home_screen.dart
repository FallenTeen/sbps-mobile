import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import '../armada/models/armada.dart';
import 'logistik_repository.dart';

/// Layar Antrean Verifikasi Ritase & Timbang untuk Role Logistik (Section 27, TD-E3).
class LogistikHomeScreen extends ConsumerStatefulWidget {
  const LogistikHomeScreen({super.key});

  @override
  ConsumerState<LogistikHomeScreen> createState() => _LogistikHomeScreenState();
}

class _LogistikHomeScreenState extends ConsumerState<LogistikHomeScreen> {
  int _selectedFilter = 0; // 0: Semua, 1: Wajib Timbang, 2: Menunggu, 3: Terverifikasi

  @override
  Widget build(BuildContext context) {
    final antreanAsync = ref.watch(antreanVerifikasiRitaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistik & Timbang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(antreanVerifikasiRitaseProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(0, 'Semua'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Wajib Timbang'),
                const SizedBox(width: 8),
                _buildFilterChip(2, 'Menunggu Verifikasi'),
                const SizedBox(width: 8),
                _buildFilterChip(3, 'Terverifikasi'),
              ],
            ),
          ),
          const Divider(height: 1),

          // List Antrean
          Expanded(
            child: antreanAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => ErrorState(
                message: friendlyErrorMessage(
                  err,
                  fallback: 'Gagal memuat antrean ritase.',
                ),
                onRetry: () =>
                    ref.invalidate(antreanVerifikasiRitaseProvider),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  if (_selectedFilter == 1) return item.wajibJembatanTimbang == true;
                  if (_selectedFilter == 2) return item.isMenungguVerifikasi;
                  if (_selectedFilter == 3) return item.isVerifiedLogistik;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(antreanVerifikasiRitaseProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        AppEmptyState(
                          icon: Icons.scale_outlined,
                          title: 'Tidak Ada Ritase',
                          subtitle: 'Belum ada data ritase dalam kategori ini.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(antreanVerifikasiRitaseProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      return _RitaseAntreanCard(
                        item: item,
                        onTap: () async {
                          final res = await context.push<bool>(
                            '/logistik/verifikasi/${item.id}',
                            extra: item,
                          );
                          if (res == true) {
                            ref.invalidate(antreanVerifikasiRitaseProvider);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilter == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = index),
    );
  }
}

class _RitaseAntreanCard extends StatelessWidget {
  const _RitaseAntreanCard({required this.item, required this.onTap});

  final RitaseItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVerified = item.isVerifiedLogistik;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.hasSelisih
              ? context.colors.error.withValues(alpha: 0.5)
              : (isVerified ? context.colors.info.withValues(alpha: 0.3) : context.colors.border),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.armadaPlat ?? 'Unit Kendaraan',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sopir: ${item.driverNama ?? 'Driver'} • ${fmtTanggal(item.tanggal)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: context.colors.info),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.info),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Butuh Verifikasi',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.colors.warning),
                      ),
                    ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Material: ${item.material ?? 'Muatan'}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Text(
                    'Driver: ${item.jumlahDriver != null ? "${item.jumlahDriver} ${item.satuanMuatan ?? 'ton'}" : "${item.jumlahRit ?? 1} rit"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (item.jumlahVerifikasiLogistik != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Hasil Timbang Resmi: ${item.jumlahVerifikasiLogistik} ton',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.colors.info,
                  ),
                ),
              ],
              if (item.ruteAsal != null || item.ruteTujuan != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${item.ruteAsal ?? '-'} → ${item.ruteTujuan ?? '-'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.hasSelisih)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 12, color: context.colors.error),
                          const SizedBox(width: 4),
                          Text(
                            'Ada Selisih',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.error),
                          ),
                        ],
                      ),
                    )
                  else if (item.wajibJembatanTimbang == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: context.colors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Wajib Timbang',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.secondary),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  BouncingButton(
                    onPressed: onTap,
                    child: Text(
                      isVerified ? 'Edit Verifikasi ›' : 'Timbang & Verifikasi ›',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
