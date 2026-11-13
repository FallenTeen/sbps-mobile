import 'package:flutter/material.dart';

/// Panduan agar pemantauan lokasi tetap berjalan di latar belakang:
/// pengecualian baterai, izin mulai otomatis, dan kunci aplikasi
/// di layar aplikasi terbaru untuk tiap merek HP.

class BatteryGuideEntry {
  const BatteryGuideEntry(this.brand, this.steps);

  final String brand;
  final List<String> steps;
}

const List<BatteryGuideEntry> kBatteryGuideEntries = [
  BatteryGuideEntry('Xiaomi (MIUI)', [
    'Buka Pengaturan, pilih Baterai, lalu pilih aplikasi ini dan set "Tanpa batasan".',
    'Buka Pengaturan, pilih Aplikasi, pilih Kelola aplikasi, buka aplikasi ini, lalu aktifkan "Mulai otomatis".',
    'Buka layar aplikasi terbaru, tekan lama kartu aplikasi ini, lalu pilih kunci (ikon gembok).',
  ]),
  BatteryGuideEntry('Oppo atau Realme (ColorOS)', [
    'Buka Pengaturan, pilih Baterai, buka aplikasi ini, lalu matikan optimasi baterai (pilih "Tidak dioptimalkan").',
    'Buka Pengaturan, pilih Aplikasi, buka aplikasi ini, lalu aktifkan "Mulai otomatis".',
    'Buka layar aplikasi terbaru, tekan lama kartu aplikasi ini, lalu pilih kunci (ikon gembok).',
  ]),
  BatteryGuideEntry('Vivo (Funtouch)', [
    'Buka Pengaturan, pilih Baterai, buka aplikasi ini, lalu izinkan penggunaan daya di latar belakang.',
    'Buka Pengaturan, pilih Aplikasi, buka aplikasi ini, lalu aktifkan "Mulai otomatis".',
    'Buka layar aplikasi terbaru, tekan lama kartu aplikasi ini, lalu pilih kunci (ikon gembok).',
  ]),
  BatteryGuideEntry('Samsung (One UI)', [
    'Buka Pengaturan, pilih Baterai, pilih Batas penggunaan baterai di latar belakang, lalu masukkan aplikasi ini ke daftar aplikasi tidak dipantau.',
    'Buka Pengaturan, pilih Aplikasi, buka aplikasi ini, pilih Baterai, lalu pilih "Tidak dioptimalkan".',
    'Buka layar aplikasi terbaru, tekan ikon aplikasi ini, lalu pilih kunci (ikon gembok).',
  ]),
  BatteryGuideEntry('HP lainnya (Android)', [
    'Buka Pengaturan, pilih Aplikasi, buka aplikasi ini, pilih Baterai, lalu pilih "Tidak dioptimalkan" atau "Tanpa batasan".',
    'Bila ada pilihan izin, aktifkan "Mulai otomatis" untuk aplikasi ini.',
    'Buka layar aplikasi terbaru, tekan lama kartu aplikasi ini, lalu pilih kunci (ikon gembok).',
  ]),
];

/// Kunci tanda "sudah pernah tampil otomatis" di app_preferences.
const String kBatteryGuideShownKey = 'battery_guide_shown_v1';

/// Syarat tampil otomatis (tampil sekali saja): presensi terbuka DAN
/// (izin masih while-in-use ATAU pemantauan belum berjalan).
bool shouldAutoShowBatteryGuide({
  required bool alreadyShown,
  required bool presensiOpen,
  required bool whileInUse,
  required bool trackingRunning,
}) {
  if (alreadyShown) return false;
  if (!presensiOpen) return false;
  return whileInUse || !trackingRunning;
}

Future<void> showBatteryGuideSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _BatteryGuideSheet(),
  );
}

class _BatteryGuideSheet extends StatelessWidget {
  const _BatteryGuideSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.battery_saver, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Panduan agar lokasi tetap aktif',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Beberapa HP mematikan aplikasi di latar belakang agar '
                'hemat baterai. Ikuti langkah sesuai merek HP Anda agar '
                'pemantauan lokasi tetap berjalan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in kBatteryGuideEntries)
                    _GuideTile(entry: entry),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideTile extends StatefulWidget {
  const _GuideTile({required this.entry});

  final BatteryGuideEntry entry;

  @override
  State<_GuideTile> createState() => _GuideTileState();
}

class _GuideTileState extends State<_GuideTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.smartphone,
            size: 22,
            color: colors.onSurfaceVariant,
          ),
          title: Text(widget.entry.brand),
          trailing: Icon(
            _open ? Icons.expand_less : Icons.expand_more,
            color: colors.onSurfaceVariant,
          ),
          onTap: () => setState(() => _open = !_open),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.entry.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.entry.steps[i],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
