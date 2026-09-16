import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sbps_mobile/features/presensi/presensi_hari_ini_card.dart';
import 'package:sbps_mobile/features/presensi/presensi_providers.dart';
import 'package:sbps_mobile/shared/utils/feedback_copy.dart';

Position _pos(DateTime timestamp) => Position(
      latitude: -6.2088,
      longitude: 106.8456,
      timestamp: timestamp,
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  group('LocationSnapshot', () {
    test('ready ketika posisi segar dan tidak loading', () {
      final snap = LocationSnapshot(position: _pos(DateTime.now()));
      expect(snap.hasPosition, isTrue);
      expect(snap.isStale, isFalse);
      expect(snap.ready, isTrue);
    });

    test('isStale ketika posisi lebih tua dari gpsStaleAfter', () {
      final snap = LocationSnapshot(
        position: _pos(
          DateTime.now().subtract(const Duration(minutes: 11)),
        ),
        acquiredAt: DateTime.now().subtract(
          Duration(minutes: gpsStaleAfter.inMinutes + 1),
        ),
      );
      expect(snap.isStale, isTrue);
      expect(snap.ready, isFalse);
    });

    test('ready false ketika loading atau tidak ada posisi', () {
      expect(const LocationSnapshot(loading: true).ready, isFalse);
      expect(const LocationSnapshot().ready, isFalse);
    });

    test('problemLabel memetakan tiap GpsProblem', () {
      expect(
        const LocationSnapshot(problem: GpsProblem.serviceDisabled).problemLabel,
        contains('GPS'),
      );
      expect(
        const LocationSnapshot(
          problem: GpsProblem.permissionDenied,
        ).problemLabel,
        contains('Izin'),
      );
      expect(
        const LocationSnapshot(problem: GpsProblem.unavailable).problemLabel,
        contains('Posisi'),
      );
      expect(const LocationSnapshot().problemLabel, isNull);
    });
  });

  group('presensiSubmissionMessage', () {
    test('queued memakai copy standar kCopyQueued', () {
      expect(
        presensiSubmissionMessage(const CheckInResult(queued: true)),
        kCopyQueued,
      );
    });

    test('luarRadius memberi pesan kontekstual', () {
      final msg = presensiSubmissionMessage(
        const CheckInResult(delivered: true, data: {
          'status_validasi': 'luar_radius',
        }),
      );
      expect(msg, contains('luar area'));
    });

    test('error memakai pesan error dari hasil', () {
      expect(
        presensiSubmissionMessage(const CheckInResult(error: 'X gagal')),
        'X gagal',
      );
    });

    test('delivered normal memakai pesan sukses', () {
      expect(
        presensiSubmissionMessage(const CheckInResult(delivered: true)),
        contains('berhasil'),
      );
    });
  });
}