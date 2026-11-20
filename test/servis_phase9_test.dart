import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/armada/models/helper.dart';
import 'package:sbps_mobile/features/armada/models/servis_armada.dart';
import 'package:sbps_mobile/features/armada/servis_providers.dart';
import 'package:sbps_mobile/features/armada/servis_status.dart';
import 'package:sbps_mobile/shared/theme/app_theme.dart';

ServisArmada _servis({
  String status = 'diajukan',
  String? kategori,
  String? alasanPenolakan,
  String? disetujuiOleh,
  String? catatanWorkshop,
  String? tanggalSelesai,
  bool butuhSparepart = true,
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
    butuhSparepart: butuhSparepart,
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

    test('status sparepart punya label workshop yang jelas', () {
      expect(servisStatusLabel('menunggu_sparepart'), 'Menunggu Sparepart');
      expect(servisStatusLabel('sparepart_tersedia'), 'Sparepart Tersedia');
    });

    test('status tak dikenal dikembalikan apa adanya (tidak mengarang)', () {
      expect(servisStatusLabel('archived'), 'archived');
    });
  });

  group('servisStatusColor', () {
    test('setiap status punya warna token tema, status tak dikenal textMuted', () {
      final colors = AppColors.light;
      expect(servisStatusColor('diajukan', colors), colors.warning);
      expect(servisStatusColor('disetujui', colors), colors.info);
      expect(servisStatusColor('dikerjakan', colors), colors.secondary);
      expect(servisStatusColor('selesai', colors), colors.success);
      expect(servisStatusColor('ditolak', colors), colors.error);
      expect(servisStatusColor('unknown', colors), colors.textMuted);
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
    test('urutan mengikuti backend 6 step', () {
      final steps = servisTimelineSteps(_servis(status: 'diajukan'));
      expect(kServisStatusOrder, [
        'diajukan',
        'disetujui',
        'dikerjakan',
        'menunggu_sparepart',
        'sparepart_tersedia',
        'selesai',
      ]);
      expect(steps.length, 6);
      expect(steps[0].label, 'Ajuan Dibuat');
      expect(steps[0].state, ServisTimelineState.current);
      expect(steps[1].state, ServisTimelineState.pending);
      expect(steps[5].state, ServisTimelineState.pending);
    });

    test('disetujui: Ajuan Dibuat done, Persetujuan current', () {
      final steps = servisTimelineSteps(
        _servis(status: 'disetujui', disetujuiOleh: 'Pak Manager'),
      );
      expect(steps[0].state, ServisTimelineState.done);
      expect(steps[1].label, 'Persetujuan');
      expect(steps[1].state, ServisTimelineState.current);
      expect(steps[2].state, ServisTimelineState.pending);
    });

    test('dikerjakan: sampai Pengerjaan Dimulai terpenuhi', () {
      final steps = servisTimelineSteps(_servis(status: 'dikerjakan'));
      expect(steps[0].state, ServisTimelineState.done);
      expect(steps[1].state, ServisTimelineState.done);
      expect(steps[2].state, ServisTimelineState.current);
      expect(steps[3].state, ServisTimelineState.pending);
    });

    test('status sparepart punya node timeline sendiri', () {
      final waiting = servisTimelineSteps(
        _servis(status: 'menunggu_sparepart'),
      );
      expect(waiting.length, 6);
      expect(waiting[2].state, ServisTimelineState.done);
      expect(waiting[3].label, 'Menunggu Sparepart');
      expect(waiting[3].state, ServisTimelineState.current);
      expect(waiting[4].state, ServisTimelineState.pending);

      final ready = servisTimelineSteps(
        _servis(status: 'sparepart_tersedia'),
      );
      expect(ready[3].state, ServisTimelineState.done);
      expect(ready[4].label, 'Sparepart Tersedia');
      expect(ready[4].state, ServisTimelineState.current);
    });

    test('tanpa sparepart: dua step sparepart ditandai tidak perlu', () {
      final steps = servisTimelineSteps(
        _servis(status: 'selesai', butuhSparepart: false),
      );
      expect(steps[3].state, ServisTimelineState.skipped);
      expect(steps[3].badge, 'Tidak perlu');
      expect(steps[4].state, ServisTimelineState.skipped);
      expect(steps[5].state, ServisTimelineState.done);
    });

    test('selesai: semua langkah aktif done', () {
      final steps = servisTimelineSteps(
        _servis(status: 'selesai', tanggalSelesai: '2026-09-10'),
      );
      for (final s in steps) {
        expect(s.state, ServisTimelineState.done);
      }
    });

    test('ditolak: Persetujuan ditandai Ditolak beserta alasannya', () {
      final steps = servisTimelineSteps(
        _servis(status: 'ditolak', alasanPenolakan: 'Unit sudah diganti'),
      );
      expect(steps.length, 6);
      expect(steps[0].state, ServisTimelineState.done);
      expect(steps[1].state, ServisTimelineState.rejected);
      expect(steps[1].badge, 'Ditolak');
      expect(steps[1].caption, 'Unit sudah diganti');
      expect(steps[5].state, ServisTimelineState.pending);
    });

    test('timeline dari backend dipetakan oleh model detail', () {
      final item = ServisArmada.fromJson({
        'id': 's2',
        'armada_id': 'a1',
        'status': 'menunggu_sparepart',
        'tanggal_ajuan': '2026-09-01',
        'keluhan': 'Mesin berisik',
        'timeline': [
          {
            'key': 'menunggu_sparepart',
            'label': 'Menunggu Sparepart',
            'state': 'current',
            'badge': 'Menunggu Sparepart',
            'at': null,
            'actor': '-',
            'details': [],
          },
        ],
      });
      expect(item.timeline, hasLength(1));
      expect(item.timeline.single.label, 'Menunggu Sparepart');
      expect(item.timeline.single.state, 'current');
    });

    test('timeline backend skipped/ditolak tetap dikenali sebagai node terminal', () {
      final item = ServisArmada.fromJson({
        'id': 's3',
        'armada_id': 'a1',
        'status': 'ditolak',
        'tanggal_ajuan': '2026-09-01',
        'keluhan': 'Mesin berisik',
        'timeline': [
          {
            'key': 'disetujui',
            'label': 'Persetujuan',
            'state': 'skipped',
            'badge': 'Ditolak',
            'details': [],
          },
          {
            'key': 'menunggu_sparepart',
            'label': 'Menunggu Sparepart',
            'state': 'skipped',
            'badge': 'Tidak perlu',
            'details': [],
          },
        ],
      });
      expect(item.timeline[0].state, 'skipped');
      expect(item.timeline[0].badge, 'Ditolak');
      expect(item.timeline[0].isRejected, isTrue);
      expect(item.timeline[1].state, 'skipped');
      expect(item.timeline[1].badge, 'Tidak perlu');
      expect(item.timeline[1].isRejected, isFalse);
    });
  });

  group('ServisArmadaPage.fromRaw', () {
    test('format array polos tetap diterima sebagai satu halaman', () {
      final page = ServisArmadaPage.fromRaw([
        {
          'id': 's1',
          'armada_id': 'a1',
          'status': 'disetujui',
          'tanggal_ajuan': '2026-09-01',
          'keluhan': 'Mesin berisik',
        },
      ]);
      expect(page.items, hasLength(1));
      expect(page.lastPage, 1);
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