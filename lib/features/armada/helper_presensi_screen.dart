import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/photo_compression_service.dart';
import 'armada_providers.dart';
import 'models/helper.dart';

class HelperPresensiScreen extends ConsumerStatefulWidget {
  const HelperPresensiScreen({super.key});

  @override
  ConsumerState<HelperPresensiScreen> createState() =>
      _HelperPresensiScreenState();
}

class _HelperPresensiScreenState extends ConsumerState<HelperPresensiScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _submittingHelperId;

  Future<void> _submitPresensi(Helper helper, String tipe) async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100, // Akan dikompresi oleh PhotoCompressionService
    );

    if (photo == null) return;

    setState(() {
      _submittingHelperId = helper.id;
    });

    try {
      final compressor = PhotoCompressionService();
      final compressedPath = await compressor.compress(photo.path);

      await ref
          .read(armadaRepositoryProvider)
          .submitHelperPresensi(
            helperId: helper.id,
            tipe: tipe,
            photoPath: compressedPath,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menyimpan presensi ${helper.nama}')),
      );

      // Refresh list
      ref.invalidate(helpersProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan yang tidak terduga')),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (_submittingHelperId == helper.id) {
            _submittingHelperId = null;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final helpersAsync = ref.watch(helpersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Helper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(helpersProvider),
          ),
        ],
      ),
      body: helpersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Gagal memuat daftar helper: $error'),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(helpersProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (helpers) {
          if (helpers.isEmpty) {
            return const Center(
              child: Text('Tidak ada helper yang ditugaskan.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(helpersProvider);
              await ref.read(helpersProvider.future);
            },
            child: ListView.separated(
              itemCount: helpers.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final helper = helpers[index];
                final isSubmitting = _submittingHelperId == helper.id;

                final bool canCheckIn = !helper.sudahCheckIn;
                final bool canCheckOut =
                    helper.sudahCheckIn && !helper.sudahCheckOut;

                String statusText = 'Belum Hadir';
                if (helper.sudahCheckOut) {
                  statusText = 'Sudah Pulang';
                } else if (helper.sudahCheckIn) {
                  statusText = 'Hadir';
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundImage: helper.fotoUrl != null
                        ? NetworkImage(helper.fotoUrl!)
                        : null,
                    child: helper.fotoUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(
                    helper.nama,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Status: $statusText'),
                  trailing: isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canCheckIn)
                              FilledButton.tonal(
                                onPressed: () =>
                                    _submitPresensi(helper, 'check_in'),
                                child: const Text('Check In'),
                              ),
                            if (canCheckOut)
                              FilledButton.tonal(
                                onPressed: () =>
                                    _submitPresensi(helper, 'check_out'),
                                child: const Text('Check Out'),
                              ),
                            if (!canCheckIn && !canCheckOut)
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                          ],
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
