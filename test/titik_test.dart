import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/presensi/models/titik.dart';
import 'package:sbps_mobile/features/titik/titik_map_view.dart';
import 'package:sbps_mobile/features/titik/titik_selector.dart';

void main() {
  group('Titik Model Tests', () {
    test('Titik parses correctly from JSON with all fields', () {
      final json = {
        'id': 'titik-01',
        'nama': 'Titik Basecamp 1',
        'latitude': -6.2088,
        'longitude': 106.8456,
        'radius_presensi_meter': 150.0,
        'proyek_id': 'proyek-99',
        'proyek_nama': 'Proyek Tol BSD',
        'status': 'aktif',
      };

      final titik = Titik.fromJson(json);
      expect(titik.id, 'titik-01');
      expect(titik.nama, 'Titik Basecamp 1');
      expect(titik.latitude, -6.2088);
      expect(titik.longitude, 106.8456);
      expect(titik.radiusPresensiMeter, 150.0);
      expect(titik.proyekId, 'proyek-99');
      expect(titik.displayProyek, 'Proyek Tol BSD');
      expect(titik.status, 'aktif');
      expect(titik.hasValidCoordinates, isTrue);
    });

    test('Titik coordinate validation handles zeroes and invalid values', () {
      const invalidTitik = Titik(
        id: 't-0',
        nama: 'Zero Point',
        latitude: 0,
        longitude: 0,
        radiusPresensiMeter: 50,
      );
      expect(invalidTitik.hasValidCoordinates, isFalse);

      const validTitik = Titik(
        id: 't-1',
        nama: 'Valid Point',
        latitude: -7.2575,
        longitude: 112.7521,
        radiusPresensiMeter: 100,
      );
      expect(validTitik.hasValidCoordinates, isTrue);
    });
  });

  group('TitikSelector Widget Tests', () {
    testWidgets('TitikSelector renders in Daftar mode initially and lazily loads',
        (tester) async {
      final titikList = [
        const Titik(
          id: 't-1',
          nama: 'Titik Satu',
          latitude: -6.2,
          longitude: 106.8,
          radiusPresensiMeter: 50,
        ),
      ];

      Titik? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitikSelector(
              titikList: titikList,
              selectedTitik: selected,
              onChanged: (t) => selected = t,
              listBuilder: (context, _) => const Text('Custom List Mode Active'),
            ),
          ),
        ),
      );

      // Verify Daftar mode is active and child is rendered
      expect(find.text('Custom List Mode Active'), findsOneWidget);
      expect(find.text('Daftar'), findsOneWidget);
      expect(find.text('Peta'), findsOneWidget);

      // Switch to Peta mode
      await tester.tap(find.text('Peta'));
      await tester.pumpAndSettle();

      // Verify list is replaced by Map view
      expect(find.text('Custom List Mode Active'), findsNothing);
      expect(find.byType(TitikMapView), findsOneWidget);
    });
  });
}
