import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sbps_mobile/features/armada/armada_providers.dart';
import 'package:sbps_mobile/features/armada/checklist_screen.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';

// Harness with ListView to ensure content is scannable in tests.

const _fotoRemUrl = 'http://localhost/foto-rem.jpg';

ArmadaSaya _armada() => const ArmadaSaya(id: 'a-1', platNomor: 'B 1234 XYZ');

ArmadaChecklistAwal _awal({required bool editable}) => ArmadaChecklistAwal(
  checklistId: 'c-1',
  bisaDiedit: editable,
  items: [
    {'bagian': 'Ban', 'kondisi': 'baik'},
    {
      'bagian': 'Rem',
      'kondisi': 'rusak',
      'catatan': 'Rem tidak pakem',
      'foto': 'armada/checklist/2026/11/abc.jpg',
      'foto_url': _fotoRemUrl,
    },
    {'bagian': 'Lampu', 'kondisi': 'baik'},
  ],
);

ArmadaChecklist _checklist({ArmadaChecklistAwal? awal}) => ArmadaChecklist(
  armadaId: 'a-1',
  platNomor: 'B 1234 XYZ',
  sudahIsi: awal != null,
  awal: awal,
  bagianDefault: const ['Ban', 'Rem', 'Lampu'],
);

Widget _wrap(List<ArmadaChecklist> checklistItems) {
  // Using the original ListView structure from ChecklistScreen is already inside the scaffold
  // We only need to provide the correct providers.
  return ProviderScope(
    overrides: [
      armadaSayaProvider.overrideWith((ref) => Future.value([_armada()])),
      checklistHariIniProvider.overrideWith((ref) => Future.value(checklistItems)),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const ChecklistScreen(),
    ),
  );
}

Finder _networkImage(String url) => find.byWidgetPredicate(
  (w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == url,
);

Future<void> _expandBagian(WidgetTester tester, String bagian) async {
  // Scroll item into view first.
  await tester.ensureVisible(find.text(bagian).first);
  await tester.pumpAndSettle();

  // Tap to expand.
  await tester.tap(find.text(bagian).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    final tmp = Directory.systemTemp.createTempSync('sbps_chk_foto_url');
    Hive.init(tmp.path);
  });

  setUp(() {
    debugNetworkImageHttpClientProvider = () => throw StateError('no network in test');
  });

  tearDown(() {
    debugNetworkImageHttpClientProvider = null;
  });

  group('ChecklistScreen item foto_url', () {
    testWidgets('thumbnail network tampil saat buka ulang checklist terkirim',
        (tester) async {
      await tester.pumpWidget(
        _wrap([_checklist(awal: _awal(editable: false))]),
      );
      await tester.pumpAndSettle();

      await _expandBagian(tester, 'Rem');
      await tester.pump();
      expect(_networkImage(_fotoRemUrl), findsOneWidget);
      expect(find.textContaining('foto tersedia'), findsWidgets);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('foto_url menandai foto tersedia tanpa file lokal',
        (tester) async {
      await tester.pumpWidget(
        _wrap([_checklist(awal: _awal(editable: true))]),
      );
      await tester.pumpAndSettle();

      await _expandBagian(tester, 'Rem');
      await tester.pump();
      expect(find.textContaining('foto tersedia'), findsWidgets);
      debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('file lokal prioritas di atas foto_url',
        (tester) async {
      final tmp = Directory.systemTemp.createTempSync('chk_local_foto');
      final foto = File('${tmp.path}${Platform.pathSeparator}foto-rem.jpg');
      foto.writeAsBytesSync(const [0, 1, 2]);

      final awal = ArmadaChecklistAwal(
        checklistId: 'c-2',
        items: [
          {'bagian': 'Ban', 'kondisi': 'baik'},
          {
            'bagian': 'Rem',
            'kondisi': 'rusak',
            'catatan': 'Rem tidak pakem',
            'foto': foto.path,
            'foto_url': _fotoRemUrl,
          },
          {'bagian': 'Lampu', 'kondisi': 'baik'},
        ],
      );
      await tester.pumpWidget(
        _wrap([_checklist(awal: awal)]),
      );
      await tester.pumpAndSettle();

      await _expandBagian(tester, 'Rem');
      await tester.pump();
      expect(_networkImage(_fotoRemUrl), findsNothing);
      // Image.file dengan cacheWidth membungkus provider dalam ResizeImage.
      expect(
        find.byWidgetPredicate((w) {
          if (w is! Image) return false;
          final img = w.image;
          return img is FileImage ||
              (img is ResizeImage && img.imageProvider is FileImage);
        }),
        findsOneWidget,
      );
      debugNetworkImageHttpClientProvider = null;
    });
  });
}