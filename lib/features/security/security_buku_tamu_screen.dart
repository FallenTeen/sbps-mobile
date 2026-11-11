import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/utils/feedback_copy.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/bouncing_button.dart';
import 'models/security_models.dart';
import 'security_repository.dart';

/// Layar Daftar Buku Tamu Hari Ini (Section 27, TD-F2).
class SecurityBukuTamuScreen extends ConsumerStatefulWidget {
  const SecurityBukuTamuScreen({super.key});

  @override
  ConsumerState<SecurityBukuTamuScreen> createState() =>
      _SecurityBukuTamuScreenState();
}

class _SecurityBukuTamuScreenState
    extends ConsumerState<SecurityBukuTamuScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _tandaiKeluar(BukuTamuRecord tamu) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tandai ${tamu.nama} Keluar?'),
        content: Text('Tamu dari "${tamu.asal}" akan dicatat jam keluarnya pada saat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tandai Keluar'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    HapticFeedback.lightImpact();
    try {
      final repo = ref.read(securityRepositoryProvider);
      await repo.tandaiKeluarBukuTamu(tamu.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tamu.nama} telah ditandai keluar.'),
          backgroundColor: Colors.green,
        ),
      );
      ref.invalidate(bukuTamuHariIniProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyErrorMessage(e, fallback: 'Gagal menandai keluar. Coba lagi.'),
          ),
          backgroundColor: context.colors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamuAsync = ref.watch(bukuTamuHariIniProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Tamu Hari Ini'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(bukuTamuHariIniProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await context.push<bool>('/security/buku-tamu/baru');
          if (res == true) {
            ref.invalidate(bukuTamuHariIniProvider);
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tamu Baru'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari nama, instansi, atau plat...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),

          // List Tamu
          Expanded(
            child: tamuAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: context.colors.error),
                      const SizedBox(height: 12),
                      Text(
                        friendlyErrorMessage(
                          err,
                          fallback: 'Gagal memuat buku tamu. Coba lagi.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(bukuTamuHariIniProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (list) {
                final filtered = list.where((t) {
                  if (_query.isEmpty) return true;
                  final matchNama = t.nama.toLowerCase().contains(_query);
                  final matchAsal = t.asal.toLowerCase().contains(_query);
                  final matchPlat = t.platNomor?.toLowerCase().contains(_query) ?? false;
                  return matchNama || matchAsal || matchPlat;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(bukuTamuHariIniProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        AppEmptyState(
                          icon: Icons.menu_book_rounded,
                          title: _query.isEmpty ? 'Belum Ada Tamu' : 'Tamu Tidak Ditemukan',
                          subtitle: _query.isEmpty
                              ? 'Belum ada catatan tamu masuk hari ini.'
                              : 'Tidak ada tamu yang cocok dengan pencarian "$_query".',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(bukuTamuHariIniProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final tamu = filtered[i];
                      return _TamuCard(
                        tamu: tamu,
                        onTandaiKeluar: () => _tandaiKeluar(tamu),
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
}

class _TamuCard extends StatelessWidget {
  const _TamuCard({required this.tamu, required this.onTandaiKeluar});

  final BukuTamuRecord tamu;
  final VoidCallback onTandaiKeluar;

  @override
  Widget build(BuildContext context) {
    final isKeluar = tamu.isSudahKeluar;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isKeluar ? context.colors.border : Colors.blue.withValues(alpha: 0.35),
        ),
      ),
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
                        tamu.nama,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Asal/Instansi: ${tamu.asal} (${tamu.jumlahOrang} orang)',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isKeluar
                        ? Colors.grey.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isKeluar ? Colors.grey.shade400 : Colors.green.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isKeluar ? 'Sudah Keluar' : 'Di Lokasi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isKeluar ? Colors.grey.shade700 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                Icon(Icons.directions_car_outlined, size: 16, color: context.colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${tamu.kendaraan.label}${tamu.platNomor != null ? ' (${tamu.platNomor})' : ''}',
                  style: const TextStyle(fontSize: 13),
                ),
                if (tamu.nomorTelepon != null && tamu.nomorTelepon!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.phone_outlined, size: 15, color: context.colors.textSecondary),
                  const SizedBox(width: 4),
                  Text(tamu.nomorTelepon!, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Masuk: ${tamu.jamMasuk.hour.toString().padLeft(2, '0')}:${tamu.jamMasuk.minute.toString().padLeft(2, '0')}'
                  '${tamu.jamKeluar != null ? " • Keluar: ${tamu.jamKeluar!.hour.toString().padLeft(2, '0')}:${tamu.jamKeluar!.minute.toString().padLeft(2, '0')}" : ""}',
                  style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                ),
                if (!isKeluar)
                  BouncingButton(
                    onPressed: onTandaiKeluar,
                    child: OutlinedButton(
                      onPressed: onTandaiKeluar,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Tandai Keluar', style: TextStyle(fontSize: 12)),
                    ),
                  ),
              ],
            ),
            if (tamu.catatan != null && tamu.catatan!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Catatan: ${tamu.catatan}',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
