import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/auth/models/user.dart';
import 'package:sbps_mobile/features/portal/portal_providers.dart';

User _user(List<String> roles) => User(
      id: 'u-1',
      name: 'Test User',
      email: 'test@example.com',
      roles: roles,
    );

void main() {
  group('kPresensiRoles', () {
    test('mencakup semua role SBPS — presensi wajib untuk semua karyawan', () {
      expect(kPresensiRoles, isNotEmpty);
      expect(
        kPresensiRoles,
        containsAll([
          'Mandor Titik',
          'SDM Lapangan Kondisional',
          'Kontraktor',
          'Owner',
          'Admin Keuangan',
          'Driver Armada',
          'Kepala Divisi Armada',
          'Workshop',
          'Inventory',
        ]),
      );
    });
  });

  group('kProyekRoles', () {
    test('memuat role armada termasuk Kepala Divisi Armada (setara kApp2Roles)',
        () {
      expect(kProyekRoles, contains('Driver Armada'));
      expect(kProyekRoles, contains('Kepala Divisi Armada'));
    });
  });

  group('canAccessPresensi', () {
    test('selalu true, termasuk Driver Armada & semua role lain', () {
      for (final role in kPresensiRoles) {
        expect(canAccessPresensi(_user([role])), isTrue,
            reason: 'role $role harus bisa presensi');
      }
      // Role yang belum dikenal pun tetap bisa presensi.
      expect(canAccessPresensi(_user(['Role Baru Masa Depan'])), isTrue);
    });
  });

  group('canAccessProyek', () {
    test('true untuk role App 2, false untuk yang tidak relevan', () {
      expect(canAccessProyek(_user(['Driver Armada'])), isTrue);
      expect(canAccessProyek(_user(['Kepala Divisi Armada'])), isTrue);
      expect(canAccessProyek(_user(['SDM Lapangan Kondisional'])), isFalse);
    });
  });

  group('autoPortal', () {
    test('Driver Armada bisa memilih 2 portal (presensi & proyek)', () {
      expect(autoPortal(_user(['Driver Armada'])), isNull,
          reason: 'null = jumlah portal > 1, tampilkan layar pemilihan portal');
    });

    test('Kepala Divisi Armada bisa memilih 2 portal (tidak terjebak layar kosong)',
        () {
      expect(autoPortal(_user(['Kepala Divisi Armada'])), isNull);
    });

    test('role presensi-only auto-pilih portal presensi', () {
      expect(autoPortal(_user(['SDM Lapangan Kondisional'])),
          AppPortal.presensi);
    });

    test('tanpa role: tetap bisa presensi (untuk user yang hanya absen)', () {
      expect(autoPortal(_user([])), AppPortal.presensi);
    });
  });
}