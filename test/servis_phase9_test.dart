import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/armada/models/helper.dart';
import 'package:sbps_mobile/features/armada/models/servis_armada.dart';
import 'package:sbps_mobile/features/armada/servis_providers.dart';
import 'package:sbps_mobile/features/armada/servis_status.dart';

ServisArmada _servis({
  String status = 'diajukan',
  String? kategori,
  String? alasanPenolakan,
  String? disetujuiOleh,
  String? catatanWorkshop,
  String? tanggalSelesai,
}) {
  return ServisArmada(
    id: 's1',
    armadaId: 'a1',
    platNomor: 'B 1234 CD',
    kodeUnit: 'U-01',
    jenisArmada: 'dump_truck',
    tanggalAjuan: '2026-09-01',
    status: status,
    keluhan: 'Mesin berisik',
    kategori: kategori,
    alasanPenolakan: alasanPenolakan,
    disetujuiOleh: disetujuiOleh,
    catatanWorkshop: catatanWorkshop,
    tanggalSelesai: tanggalSelesai,
  );
}

void main() {
  group('servisStatusLabel', () {
    test('memetakan semua status wire ke label user-facing yang jelas', () {
      expect(servisStatusLabel('diajukan'), 'Menunggu Persetujuan');
      expect(servisStatusLabel('disetujui'), 'Disetujui');
      expect(servisStatusLabel('dikerjakan'), 'Sedang Dikerjakan');
      expect(servisStatusLabel('selesai'), 'Selesai');
      expect(servisStatusLabel('ditolak'), 'Ditolak');
    });

    test('status tak dikenal dikembalikan apa adanya (tidak mengarang)', () {
      expect(servisStatusLabel('archived'), 'archived');
    });
  });

  group('servisStatusColor', () {
    test('setiap status punya warna, status tak dikenal abu-abu', () {
      expect(servisStatusColor('diajukan'), Colors.orange);
      expect(servisStatusColor('disetujui'), Colors.blue);
      expect(servisStatusColor('dikerjakan'), Colors.purple);
      expect(servisStatusColor('selesai'), Colors.green);
      expect(servisStatusColor('ditolak'), Colors.red);
      expect(servisStatusColor('unknown'), Colors.grey);
    });
  });

  group('formatKategoriServis', () {
    test('memetakan kategori ke label user-facing', () {
      expect(formatKategoriServis('rutin'), 'Servis Rutin / Berkala');
      expect(formatKategoriServis('kerusakan'), 'Perbaikan Kerusakan');
      expect(formatKategoriServis('darurat'), 'Darurat / Mogok');
      expect(formatKategoriServis('ganti_oli'), 'Ganti Oli / Pelumas');
      expect(formatKategoriServis('lainnya'), 'lainnya');
    });
  });

  group('canApproveServis', () {
    test('role approval boleh setujui/tolak servis', () {
      expect(canApproveServis('Kepala Divisi Armada'), isTrue);
      expect(canApproveServis('Owner'), isTrue);
      expect(canApproveServis('Admin Keuangan'), isTrue);
      expect(canApproveServis('Admin'), isTrue);
    });

    test('role non-approval tidak bisa', () {
      expect(canApproveServis('Driver Armada'), isFalse);
      expect(canApproveServis('Karyawan'), isFalse);
      expect(canApproveServis(null), isFalse);
    });
  });

  group('servisNextAction', () {
    test('diajukan: approver = aksi nyata, non-approver = menunggu', () {
      expect(
        servisNextAction(_servis(status: 'diajukan'), canApprove: true),
        contains('Setujui / Tolak'),
      );
      expect(
        servisNextAction(_servis(status: 'diajukan'), canApprove: false),
        contains('Menunggu persetujuan'),
      );
    });

    test('status lanjutan memakai label tindak lanjut yang sesuai', () {
      expect(servisNextAction(_servis(status: 'disetujui')),
          contains('Menunggu dijadwalkan'));
      expect(servisNextAction(_servis(status: 'dikerjakan')),
          contains('Sedang dikerjakan'));
      expect(servisNextAction(_servis(status: 'selesai')),
          contains('Selesai'));
      expect(servisNextAction(_servis(status: 'ditolak')),
          contains('Ditolak'));
    });
  });

  group('servisTimelineSteps', () {
    test('diajukan: langkah 1 current, sisanya pending', () {
      final steps = servisTimelineSteps(_servis(status: 'diajukan'));
      expect(steps.length, 4);
      expect(steps[0].label, 'Diajukan');
      expect(steps[0].state, ServisTimelineState.current);
      expect(steps[1].state, ServisTimelineState.pending);
      expect(steps[2].state, ServisTimelineState.pending);
      expect(steps[3].state, ServisTimelineState.pending);
    });

    test('disetujui: Diajukan done, Disetujui current', () {
      final steps = servisTimelineSteps(
        _servis(status: 'disetujui', disetujuiOleh: 'Pak Manager'),
      );
      expect(steps[0].state, ServisTimelineState.done);
      expect(steps[1].label, 'Disetujui');
      expect(steps[1].state, ServisTimelineState.current);
      expect(steps[2].state, ServisTimelineState.pending);
    });

    test('dikerjakan: sampai Dikerjakan terpenuhi', () {
      final steps = servisTimelineSteps(_servis(status: 'dikerjakan'));
      expect(steps[0].state, ServisTimelineState.done);
      expect(steps[1].state, ServisTimelineState.done);
      expect(steps[2].state, ServisTimelineState.current);
      expect(steps[3].state, ServisTimelineState.pending);
    });

    test('selesai: semua langkah done', () {
      final steps = servisTimelineSteps(
        _servis(status: 'selesai', tanggalSelesai: '2026-09-10'),
      );
      for (final s in steps) {
        expect(s.state, ServisTimelineState.done);
      }
    });

    test('ditolak: node terminal Ditolak merujuk alasan penolakan', () {
      final steps = servisTimelineSteps(
        _servis(status: 'ditolak', alasanPenolakan: 'Unit sudah diganti'),
      );
      expect(steps.length, 5);
      expect(steps[0].state, ServisTimelineState.done);
      expect(steps.last.label, 'Ditolak');
      expect(steps.last.state, ServisTimelineState.rejected);
      expect(steps.last.caption, 'Unit sudah diganti');
    });
  });

  group('ServisQueueSummary', () {
    test('countFor memetakan status ke jumlah yang benar', () {
      const summary = ServisQueueSummary(
        diajukan: 2,
        disetujui: 1,
        dikerjakan: 3,
        selesai: 5,
        ditolak: 0,
      );
      expect(summary.countFor('diajukan'), 2);
      expect(summary.countFor('disetujui'), 1);
      expect(summary.countFor('dikerjakan'), 3);
      expect(summary.countFor('selesai'), 5);
      expect(summary.countFor('ditolak'), 0);
      expect(summary.countFor('unknown'), 0);
    });
  });

  group('Helper status', () {
    test('null = Belum Masuk, next action Presensi Masuk', () {
      const h = Helper(id: '1', nama: 'Budi');
      expect(h.statusHariIniLabel, 'Belum Masuk');
      expect(h.nextActionLabel, 'Presensi Masuk');
      expect(h.sudahCheckIn, isFalse);
      expect(h.sudahCheckOut, isFalse);
    });

    test('check_in = Sedang Bekerja, next action Presensi Pulang', () {
      const h = Helper(id: '1', nama: 'Andi', statusHariIni: 'check_in');
      expect(h.statusHariIniLabel, 'Sedang Bekerja');
      expect(h.nextActionLabel, 'Presensi Pulang');
      expect(h.sudahCheckIn, isTrue);
      expect(h.sudahCheckOut, isFalse);
    });

    test('check_out = Sudah Pulang, tidak ada next action', () {
      const h = Helper(id: '1', nama: 'Cici', statusHariIni: 'check_out');
      expect(h.statusHariIniLabel, 'Sudah Pulang');
      expect(h.nextActionLabel, isNull);
      expect(h.sudahCheckIn, isTrue);
      expect(h.sudahCheckOut, isTrue);
    });
  });
}