import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/armada/models/servis_armada.dart';
import 'package:sbps_mobile/features/inventory/inventory_models.dart';
import 'package:sbps_mobile/features/workshop/workshop_models.dart';
import 'package:sbps_mobile/features/workshop/workshop_repository.dart';
import 'package:sbps_mobile/features/workshop/workshop_rules.dart';

ServisArmada _servis(String status, {String id = 'j1'}) {
  return ServisArmada(
    id: id,
    armadaId: 'a1',
    platNomor: 'B 1234 XYZ',
    kategori: 'rutin',
    tanggalAjuan: '2026-09-16 08:00:00',
    status: status,
    keluhan: 'Mesin bunyi',
    diajukanOleh: 'Pak Budi',
    odometerSaatAjuan: 125000,
    tanggalSelesai: status == 'selesai' ? '2026-09-16 12:00:00' : null,
  );
}

WorkshopJob _job(String status, {String id = 'j1'}) =>
    WorkshopJob.fromServisArmada(_servis(status, id: id));

List<Map<String, dynamic>> _rawServisItems(List<String> statuses) {
  return [
    for (var i = 0; i < statuses.length; i++)
      {
        'id': 'j$i',
        'armada_id': 'a$i',
        'plat_nomor': 'B 1234 XY$i',
        'keluhan': 'Keluhan $i',
        'tanggal_ajuan': '2026-09-16 08:00:00',
        'status': statuses[i],
        if (statuses[i] == 'selesai') 'tanggal_selesai': '2026-09-16 11:00:00',
      },
  ];
}

InventoryRequest _req(String jobId, InventoryRequestStatus status) {
  return InventoryRequest(
    id: 'req-$jobId',
    workshopJobId: jobId,
    platNomor: 'B 1234 XYZ',
    kategoriServis: 'rutin',
    status: status,
    items: [
      InventoryRequestItem(
        id: 'i1',
        namaBarang: 'Oli Mesin',
        jumlahDiminta: 4,
        satuan: 'L',
        status: InventoryRequestItemStatus.tersedia,
      ),
    ],
    createdAt: DateTime(2026, 9, 16, 9, 0),
  );
}

void main() {
  group('Antrian Workshop — reject tidak masuk pending', () {
    test('antrianFromRaw hanya mempertahankan disetujui/dikerjakan/selesai', () {
      final jobs = WorkshopRepository.antrianFromRaw(_rawServisItems([
        'diajukan',
        'disetujui',
        'ditolak',
        'dikerjakan',
        'selesai',
      ]));
      expect(jobs.length, 3);
      expect(jobs.map((j) => j.status), [
        WorkshopJobStatus.menunggu, // disetujui
        WorkshopJobStatus.dikerjakan,
        WorkshopJobStatus.selesai,
      ]);
    });

    test('antrianFromRaw menangani pembungkus {data: []}', () {
      final jobs = WorkshopRepository.antrianFromRaw({
        'data': _rawServisItems(['ditolak', 'disetujui']),
      });
      expect(jobs.length, 1);
      expect(jobs.single.status, WorkshopJobStatus.menunggu);
    });

    test('ditolak/diajukan bukan pekerjaan workshop', () {
      expect(WorkshopRepository.isWorkForWorkshop(_servis('ditolak')), isFalse);
      expect(WorkshopRepository.isWorkForWorkshop(_servis('diajukan')), isFalse);
    });
  });

  group('Selesai Hari Ini — benar-benar berdasarkan tanggal', () {
    final now = DateTime(2026, 9, 16, 12, 0);

    test('isTodayFor mencocokkan hari yang sama', () {
      expect(isTodayFor(DateTime(2026, 9, 16, 1, 30), now), isTrue);
      expect(isTodayFor(DateTime(2026, 9, 15, 23, 0), now), isFalse);
      expect(isTodayFor(null, now), isFalse);
    });

    test('selesaiHariIni hanya job selesai tanggal hari ini', () {
      final today = _job('selesai', id: 'today');
      final yesterdayServis = ServisArmada(
        id: 'y',
        armadaId: 'a',
        tanggalAjuan: '',
        status: 'selesai',
        keluhan: '',
        tanggalSelesai: '2026-09-15 10:00:00',
      );
      final yesterday = WorkshopJob.fromServisArmada(yesterdayServis);
      final dikerjakan = _job('dikerjakan', id: 'd1');

      final result = selesaiHariIni([today, yesterday, dikerjakan], now);
      expect(result.map((j) => j.id), ['today']);
    });
  });

  group('Menunggu Sparepart — dari request inventori nyata', () {
    test('hanya request pending/diproses yang dihitung', () {
      final jobs = [
        _job('dikerjakan', id: 'j1'),
        _job('menunggu', id: 'j2'),
        _job('selesai', id: 'j3'),
      ];
      final requests = [
        _req('j1', InventoryRequestStatus.pending),
        _req('j2', InventoryRequestStatus.diproses),
        _req('j3', InventoryRequestStatus.pending), // job selesai — dikecualikan
        _req('ghost', InventoryRequestStatus.pending), // bukan job di antrian
        InventoryRequest(
          id: 'x',
          workshopJobId: 'j1',
          platNomor: 'B',
          kategoriServis: '-',
          status: InventoryRequestStatus.ditolak,
          items: const [],
          createdAt: DateTime.now(),
        ), // ditolak — tidak menunggu
      ];
      final waiting = sparepartWaitingJobIds(jobs, requests);
      expect(waiting, {'j1', 'j2'});
      expect(countMenungguSparepart(jobs, waiting), 2);
    });

    test('job 0-item / selesai tidak menambah menunggu sparepart', () {
      final jobs = [_job('selesai', id: 's1')];
      final waiting = sparepartWaitingJobIds(jobs, [_req('s1', InventoryRequestStatus.pending)]);
      expect(waiting, isEmpty);
    });
  });

  group('Kelayakan Tandai Selesai', () {
    WorkshopTodoItem item(String id, {bool done = false, String? photo}) =>
        WorkshopTodoItem(
          id: id,
          jobId: 'j1',
          label: 'Cek mesin',
          isDone: done,
          photoPath: photo,
        );

    test('status menunggu diblokir', () {
      final check = workshopCanComplete(
        status: WorkshopJobStatus.menunggu,
        todos: [item('a', done: true, photo: '/tmp/x.jpg')],
      );
      expect(check.allowed, isFalse);
      expect(check.reason, contains('Mulai pengerjaan'));
    });

    test('job 0-item TIDAK otomatis bisa selesai', () {
      final check = workshopCanComplete(
        status: WorkshopJobStatus.dikerjakan,
        todos: const [],
      );
      expect(check.allowed, isFalse);
      expect(check.reason, contains('belum punya item'));
    });

    test('item belum semua selesai diblokir', () {
      final check = workshopCanComplete(
        status: WorkshopJobStatus.dikerjakan,
        todos: [item('a', done: true, photo: '/tmp/x.jpg'), item('b')],
      );
      expect(check.allowed, isFalse);
      expect(check.reason, contains('Selesaikan semua item'));
    });

    test('item selesai tanpa foto bukti diblokir', () {
      final check = workshopCanComplete(
        status: WorkshopJobStatus.dikerjakan,
        todos: [item('a', done: true)],
      );
      expect(check.allowed, isFalse);
      expect(check.reason, contains('foto bukti'));
    });

    test('semua item selesai + foto bukti lengkap = boleh', () {
      final check = workshopCanComplete(
        status: WorkshopJobStatus.dikerjakan,
        todos: [
          item('a', done: true, photo: '/tmp/a.jpg'),
          item('b', done: true, photo: '/tmp/b.jpg'),
        ],
      );
      expect(check.allowed, isTrue);
      expect(check.reason, isNull);
    });

    test('status selesai tidak bisa di-set ulang', () {
      final check = workshopCanComplete(
        status: WorkshopJobStatus.selesai,
        todos: [item('a', done: true, photo: '/tmp/a.jpg')],
      );
      expect(check.allowed, isFalse);
    });
  });

  group('Langkah berikutnya (next action)', () {
    test('sesuai status + keadaan sparepart', () {
      expect(
        workshopNextAction(_job('menunggu'), waitingSparepart: false),
        'Mulai Pengerjaan',
      );
      expect(
        workshopNextAction(_job('dikerjakan'), waitingSparepart: true),
        contains('Menunggu sparepart'),
      );
      expect(
        workshopNextAction(_job('dikerjakan'), waitingSparepart: false),
        contains('Selesaikan item'),
      );
      expect(
        workshopNextAction(_job('selesai'), waitingSparepart: false),
        contains('sudah selesai'),
      );
    });
  });

  group('Detail job — data lengkap dari servis', () {
    test('WorkshopJobDetail.fromJson mengurai pengaju, ODO, todos', () {
      final detail = WorkshopJobDetail.fromJson({
        'id': 'j1',
        'armada_id': 'a1',
        'plat_nomor': 'B 1234 XYZ',
        'keluhan': 'Mesin bunyi',
        'kategori': 'rutin',
        'tanggal_ajuan': '2026-09-16 08:00:00',
        'status': 'dikerjakan',
        'diajukan_oleh': 'Pak Budi',
        'odometer_saat_ajuan': 125000,
        'todos': [
          {'id': 't1', 'job_id': 'j1', 'label': 'Cek oli', 'is_done': true},
          {'id': 't2', 'job_id': 'j1', 'label': 'Ganti filter'},
        ],
      });

      expect(detail.servis.diajukanOleh, 'Pak Budi');
      expect(detail.servis.odometerSaatAjuan, 125000);
      expect(detail.job.platNomor, 'B 1234 XYZ');
      expect(detail.job.status, WorkshopJobStatus.dikerjakan);
      expect(detail.todos.length, 2);
      expect(detail.todos.first.isDone, isTrue);
      expect(workshopCompletedCount(detail.todos), 1);
    });

    test('bisa lengkap dengan foto bukti (copyWith)', () {
      final t = const WorkshopTodoItem(
        id: 't1',
        jobId: 'j1',
        label: 'Cek',
        isDone: true,
      ).copyWith(photoPath: '/tmp/ev.jpg');
      expect(t.photoPath, '/tmp/ev.jpg');
    });
  });
}