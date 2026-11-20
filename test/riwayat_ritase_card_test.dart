import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';
import 'package:sbps_mobile/features/armada/riwayat_ritase_screen.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';

void main() {
  testWidgets('kartu ritase memanggil onTap dan memakai path detail', (tester) async {
    final ritase = RitaseItem(
      id: 'ritase-42',
      tanggal: '2026-11-20',
      material: 'Pasir',
      jumlahRit: 2,
      status: 'draft',
    );
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: RitaseListCard(
          ritase: ritase,
          onTap: () => tapped = true,
        ),
      ),
    ));

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(tapped, isTrue);
    expect(ritaseDetailPath(ritase), '/armada/ritase/ritase-42');
  });

  testWidgets('tombol selesaikan memanggil onSelesai tanpa membuka detail', (tester) async {
    final ritase = RitaseItem(
      id: 'ritase-43',
      tanggal: '2026-11-20',
      status: 'draft',
      bisaSelesaikan: true,
    );
    var detailTapped = false;
    var selesaiTapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: RitaseListCard(
          ritase: ritase,
          onTap: () => detailTapped = true,
          onSelesai: () => selesaiTapped = true,
        ),
      ),
    ));

    await tester.tap(find.text('Selesaikan Ritase'));
    await tester.pump();

    expect(selesaiTapped, isTrue);
    expect(detailTapped, isFalse);
  });
}
