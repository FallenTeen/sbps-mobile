import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/proyek/role_permissions.dart';

/// Peta key modul → index branch shell (sama dengan `_proyekBranchByModule`
/// di `lib/core/app_router.dart`). Dipakai [navBranchFor] sebagai parameter.
const _moduleBranchByKey = <String, int>{
  'produksi': 1,
  'qc': 2,
  'tracking': 3,
  'dashboard': 4,
  'keuangan': 5,
  'armada': 6,
  'kontraktor': 7,
  'workshop': 8,
  'inventory': 9,
};

List<String> _keysOf(String? role) =>
    buildNavDestinations(role).map((d) => d.key).toList();

void main() {
  group('buildNavDestinations (≤ 4, task-first, single shell)', () {
    test('Driver Armada → Beranda + Presensi + Notifikasi (pekerjaan = Beranda)',
        () {
      expect(_keysOf('Driver Armada'), ['home', 'presensi', 'notifikasi']);
    });

    test('Workshop → Beranda + Presensi + Notifikasi', () {
      expect(_keysOf('Workshop'), ['home', 'presensi', 'notifikasi']);
    });

    test('Inventory → Beranda + Presensi + Notifikasi', () {
      expect(_keysOf('Inventory'), ['home', 'presensi', 'notifikasi']);
    });

    test('Mandor Titik → Beranda + Tugas + Presensi + Notifikasi (4)', () {
      expect(_keysOf('Mandor Titik'),
          ['home', 'tugas', 'presensi', 'notifikasi']);
    });

    test('Kepala Divisi Armada → Beranda + Tugas + Presensi + Notifikasi', () {
      expect(_keysOf('Kepala Divisi Armada'),
          ['home', 'tugas', 'presensi', 'notifikasi']);
    });

    test('Owner → Beranda + Tugas + Presensi + Notifikasi (4)', () {
      expect(_keysOf('Owner'), ['home', 'tugas', 'presensi', 'notifikasi']);
    });

    test('Admin Keuangan → Beranda + Tugas + Presensi + Notifikasi', () {
      expect(_keysOf('Admin Keuangan'),
          ['home', 'tugas', 'presensi', 'notifikasi']);
    });

    test('Kontraktor → Beranda + Tugas + Presensi + Notifikasi', () {
      expect(_keysOf('Kontraktor'),
          ['home', 'tugas', 'presensi', 'notifikasi']);
    });

    test('tidak pernah melebihi 4 destination', () {
      for (final role in [
        'Driver Armada',
        'Workshop',
        'Inventory',
        'Mandor Titik',
        'Owner',
        'Admin Keuangan',
        'Kepala Divisi Armada',
        'Kontraktor',
      ]) {
        expect(buildNavDestinations(role).length, lessThanOrEqualTo(4),
            reason: 'role $role');
      }
    });

    test('role baru/tidak dikenal → Beranda + Notifikasi saja', () {
      expect(_keysOf('Role Masa Depan'), ['home', 'notifikasi']);
      expect(_keysOf(null), ['home', 'notifikasi']);
    });
  });

  group('appHomeKindFor (Beranda role-aware)', () {
    test('portal presensi selalu → beranda presensi (apa pun rolenya)', () {
      expect(
        appHomeKindFor(role: 'Mandor Titik', presensiPortal: true),
        AppHomeKind.presensi,
      );
      expect(
        appHomeKindFor(role: null, presensiPortal: true),
        AppHomeKind.presensi,
      );
    });

    test('tanpa role di portal proyek → fallback presensi', () {
      expect(
        appHomeKindFor(role: null, presensiPortal: false),
        AppHomeKind.presensi,
      );
    });

    test('Driver Armada → driver (Pekerjaan Hari Ini)', () {
      expect(
        appHomeKindFor(role: 'Driver Armada', presensiPortal: false),
        AppHomeKind.driver,
      );
    });

    test('Workshop → workshop (Antrian Hari Ini)', () {
      expect(
        appHomeKindFor(role: 'Workshop', presensiPortal: false),
        AppHomeKind.workshop,
      );
    });

    test('Inventory → inventory (Perhatian Hari Ini)', () {
      expect(
        appHomeKindFor(role: 'Inventory', presensiPortal: false),
        AppHomeKind.inventory,
      );
    });

    test('role manajemen → proyek (module cards penuh)', () {
      for (final role in [
        'Mandor Titik',
        'Owner',
        'Admin Keuangan',
        'Kepala Divisi Armada',
        'Kontraktor',
      ]) {
        expect(
          appHomeKindFor(role: role, presensiPortal: false),
          AppHomeKind.proyek,
          reason: 'role $role',
        );
      }
    });
  });

  group('tugasModuleFor (isi tab Tugas / Operasional)', () {
    test('Tugas = modul utama per role multi-modul', () {
      expect(tugasModuleFor('Mandor Titik'), 'produksi');
      expect(tugasModuleFor('Owner'), 'dashboard');
      expect(tugasModuleFor('Admin Keuangan'), 'keuangan');
      expect(tugasModuleFor('Kepala Divisi Armada'), 'armada');
      expect(tugasModuleFor('Kontraktor'), 'kontraktor');
    });

    test('null untuk field worker (pekerjaan ada di Beranda)', () {
      expect(tugasModuleFor('Driver Armada'), isNull);
      expect(tugasModuleFor('Workshop'), isNull);
      expect(tugasModuleFor('Inventory'), isNull);
      expect(tugasModuleFor(null), isNull);
      expect(tugasModuleFor('Role Masa Depan'), isNull);
    });
  });

  group('navBranchFor (mapping destination → shell branch)', () {
    test('Beranda → branch 0 untuk semua role', () {
      expect(navBranchFor('home', 'Owner', _moduleBranchByKey), 0);
      expect(navBranchFor('home', 'Driver Armada', _moduleBranchByKey), 0);
      expect(navBranchFor('home', null, _moduleBranchByKey), 0);
    });

    test('Presensi → branch 10, Notifikasi → branch 11', () {
      expect(
        navBranchFor('presensi', 'Owner', _moduleBranchByKey),
        kPresensiBranchIndex,
      );
      expect(
        navBranchFor('notifikasi', 'Owner', _moduleBranchByKey),
        kNotifikasiBranchIndex,
      );
      expect(kPresensiBranchIndex, 10);
      expect(kNotifikasiBranchIndex, 11);
    });

    test('Tugas mengikuti modul utama role', () {
      expect(navBranchFor('tugas', 'Mandor Titik', _moduleBranchByKey),
          _moduleBranchByKey['produksi']);
      expect(navBranchFor('tugas', 'Owner', _moduleBranchByKey),
          _moduleBranchByKey['dashboard']);
      expect(navBranchFor('tugas', 'Admin Keuangan', _moduleBranchByKey),
          _moduleBranchByKey['keuangan']);
      expect(navBranchFor('tugas', 'Kepala Divisi Armada', _moduleBranchByKey),
          _moduleBranchByKey['armada']);
      expect(navBranchFor('tugas', 'Kontraktor', _moduleBranchByKey),
          _moduleBranchByKey['kontraktor']);
    });

    test('Tugas tanpa modul → fallback Beranda (branch 0)', () {
      expect(navBranchFor('tugas', 'Driver Armada', _moduleBranchByKey), 0);
      expect(navBranchFor('tugas', null, _moduleBranchByKey), 0);
    });

    test('key modul → branch modulnya', () {
      for (final entry in _moduleBranchByKey.entries) {
        expect(navBranchFor(entry.key, 'Owner', _moduleBranchByKey), entry.value);
      }
    });
  });
}