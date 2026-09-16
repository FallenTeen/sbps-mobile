import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';
import 'package:sbps_mobile/shared/widgets/action_card.dart';
import 'package:sbps_mobile/shared/widgets/app_empty_state.dart';
import 'package:sbps_mobile/shared/widgets/app_error_state.dart';
import 'package:sbps_mobile/shared/widgets/form_section.dart';
import 'package:sbps_mobile/shared/widgets/key_value_row.dart';
import 'package:sbps_mobile/shared/widgets/page_header.dart';
import 'package:sbps_mobile/shared/widgets/section_header.dart';
import 'package:sbps_mobile/shared/widgets/sticky_action_bar.dart';
import 'package:sbps_mobile/shared/widgets/summary_card.dart';
import 'package:sbps_mobile/shared/widgets/timeline.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('Phase 03 Design System widgets', () {
    testWidgets('PageHeader renders title, subtitle and action', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PageHeader(
            title: 'Judul Halaman',
            subtitle: 'Deskripsi singkat',
            action: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.text('Judul Halaman'), findsOneWidget);
      expect(find.text('Deskripsi singkat'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Judul Halaman')).hasFlag(
          SemanticsFlag.isHeader,
        ),
        isTrue,
      );
    });

    testWidgets('SectionHeader renders title and trailing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SectionHeader(
            title: 'Daftar Item',
            trailing: TextButton(onPressed: () {}, child: const Text('Lihat')),
          ),
        ),
      );
      expect(find.text('Daftar Item'), findsOneWidget);
      expect(find.text('Lihat'), findsOneWidget);
    });

    testWidgets('SummaryCard renders gradient card with value & badge',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SummaryCard(
            title: 'Ringkasan Sesi',
            value: '5 sesi aktif',
            subtitle: '2 menunggu QC',
            badge: const Text('3', style: TextStyle(color: Colors.white)),
          ),
        ),
      );
      expect(find.text('Ringkasan Sesi'), findsOneWidget);
      expect(find.text('5 sesi aktif'), findsOneWidget);
      expect(find.text('2 menunggu QC'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('ActionCard invokes onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ActionCard(
            icon: Icons.play_circle_outline,
            title: 'Mulai Ritase',
            subtitle: 'Catat muatan unit',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Mulai Ritase'), findsOneWidget);
      await tester.tap(find.text('Mulai Ritase'));
      expect(tapped, isTrue);
    });

    testWidgets('FormSection renders title and children with spacing',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormSection(
            title: 'Data Unit',
            children: [
              TextField(controller: TextEditingController()),
              TextField(controller: TextEditingController()),
            ],
          ),
        ),
      );
      expect(find.text('Data Unit'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('StickyActionBar renders primary + secondary & fires',
        (tester) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              const Expanded(child: SizedBox()),
              StickyActionBar(
                primaryLabel: 'Simpan',
                onPrimary: () => primary++,
                secondaryLabel: 'Batal',
                onSecondary: () => secondary++,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Simpan'));
      await tester.tap(find.text('Batal'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('Timeline renders items with status variants', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Timeline(
            items: const [
              TimelineItem(
                title: 'Diterima',
                subtitle: '10:00',
                status: TimelineStatus.done,
              ),
              TimelineItem(title: 'Dikerjakan', status: TimelineStatus.current),
              TimelineItem(title: 'Belum', status: TimelineStatus.pending),
            ],
          ),
        ),
      );
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Dikerjakan'), findsOneWidget);
      expect(find.text('Belum'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('KeyValueRow renders label & value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const KeyValueRow(label: 'Status', value: 'Aktif'),
        ),
      );
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
    });

    testWidgets('ErrorState renders message and retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          ErrorState(
            message: 'Gagal memuat data',
            detail: 'Tidak ada koneksi',
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text('Gagal memuat data'), findsOneWidget);
      expect(find.text('Tidak ada koneksi'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await tester.tap(find.text('Coba Lagi'));
      expect(retried, isTrue);
    });

    testWidgets('AppEmptyState action can also come from ErrorState default',
        (tester) async {
      await tester.pumpWidget(
        _wrap(ErrorState(message: 'Gagal muat', onRetry: () {})),
      );
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('dark theme renders SummaryCard without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SummaryCard(
              title: 'Ringkasan',
              value: '10 unit',
              badge: const Text('2', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      );
      expect(find.text('10 unit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}