import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/armada/models/servis_armada.dart';
import 'package:sbps_mobile/features/workshop/workshop_models.dart';
import 'package:sbps_mobile/features/workshop/workshop_repository.dart';

void main() {
  group('WorkshopJob status mapping', () {
    ServisArmada servisWith(String status) => ServisArmada.fromJson({
          'id': 'j1',
          'armada_id': 'a1',
          'plat_nomor': 'B 1234 XYZ',
          'keluhan': 'Mesin bunyi',
          'tanggal_ajuan': '2026-01-01 08:00:00',
          'status': status,
        });

    test('disetujui -> menunggu', () {
      final job = WorkshopJob.fromServisArmada(servisWith('disetujui'));
      expect(job.status, WorkshopJobStatus.menunggu);
    });

    test('dikerjakan -> dikerjakan', () {
      final job = WorkshopJob.fromServisArmada(servisWith('dikerjakan'));
      expect(job.status, WorkshopJobStatus.dikerjakan);
    });

    test('selesai -> selesai', () {
      final job = WorkshopJob.fromServisArmada(servisWith('selesai'));
      expect(job.status, WorkshopJobStatus.selesai);
    });

    test('ditolak BUKAN pekerjaan workshop (isWorkForWorkshop false)', () {
      final rejected = servisWith('ditolak');
      expect(WorkshopRepository.isWorkForWorkshop(rejected), isFalse);
    });

    test('diajukan BUKAN pekerjaan workshop (isWorkForWorkshop false)', () {
      final diajukan = servisWith('diajukan');
      expect(WorkshopRepository.isWorkForWorkshop(diajukan), isFalse);
    });

    test('disetujui/dikerjakan/selesai adalah pekerjaan workshop', () {
      expect(
        WorkshopRepository.isWorkForWorkshop(servisWith('disetujui')),
        isTrue,
      );
      expect(
        WorkshopRepository.isWorkForWorkshop(servisWith('dikerjakan')),
        isTrue,
      );
      expect(
        WorkshopRepository.isWorkForWorkshop(servisWith('selesai')),
        isTrue,
      );
    });
  });
}