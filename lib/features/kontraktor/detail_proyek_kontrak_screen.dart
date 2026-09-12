import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/formatters.dart';
import '../../shared/widgets/breadcrumb_title.dart';
import 'kontraktor_providers.dart';
import '../../shared/widgets/portal_switch_button.dart';

/// Detail Proyek Kontrak Klien: Ringkasan Produksi, Realisasi RAB, Invoices, dan Chat Komunikasi.
class DetailProyekKontrakScreen extends ConsumerStatefulWidget {
  const DetailProyekKontrakScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<DetailProyekKontrakScreen> createState() =>
      _DetailProyekKontrakScreenState();
}

class _DetailProyekKontrakScreenState
    extends ConsumerState<DetailProyekKontrakScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(kontraktorRepositoryProvider).sendMessage(
            proyekId: widget.id,
            pesan: text,
          );
      _messageController.clear();
      ref.invalidate(detailProyekKontrakProvider(widget.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pesan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(detailProyekKontrakProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        title: const BreadcrumbTitle(
          parentLabel: 'Kontraktor',
          title: 'Detail Proyek Kontrak',
        ),
        actions: const [PortalSwitchButton()],
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat detail proyek: $err'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(detailProyekKontrakProvider(widget.id)),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
        data: (data) {
          final p = data.proyek;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nama,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kode: ${p.kodeProyek}${p.client != null ? ' • Klien: ${p.client}' : ''}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      if (p.lokasi != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Lokasi: ${p.lokasi!}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // RAB Agregat Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Realisasi Anggaran (RAB)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Rencana:'),
                          Text(
                            fmtRp(data.totalRencana),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Realisasi:'),
                          Text(
                            fmtRp(data.totalRealisasi),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: data.totalRencana > 0
                            ? (data.totalRealisasi / data.totalRencana).clamp(0.0, 1.0)
                            : 0.0,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${fmtNum(data.persentaseRab)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Progress Produksi Summary
              if (data.produksiSummary.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress Produksi',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Divider(height: 16),
                        for (final prod in data.produksiSummary)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  prod.nama,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${fmtNum(prod.totalOutput)} ${prod.satuan} (${prod.sesiCount} sesi)',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Komunikasi / Chat Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Komunikasi Proyek',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(height: 16),
                      if (data.komunikasiLogs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Belum ada riwayat percakapan.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        for (final msg in data.komunikasiLogs)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: msg.pengirimRole == 'kontraktor'
                                  ? Colors.blue.withValues(alpha: 0.08)
                                  : Colors.green.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      msg.pengirim,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      msg.pengirimRole.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(msg.pesan),
                              ],
                            ),
                          ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Tulis pesan...',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 2,
                              minLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _isSending ? null : _sendMessage,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
