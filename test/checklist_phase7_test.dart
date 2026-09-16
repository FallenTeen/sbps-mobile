import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/features/armada/checklist_model.dart';
import 'package:sbps_mobile/features/armada/models/armada.dart';

void main() {
  ArmadaChecklist unit({
    required String id,
    required bool sudahIsi,
    bool? kondisiBaik,
  }) => ArmadaChecklist(
    armadaId: id,
    platNomor: 'P $id',
    sudahIsi: sudahIsi,
    kondisiBaik: kondisiBaik,
  );

  group('checklistSummary', () {
    test('menghitung checked / menunggu / bermasalah', () {
      final items = [
        unit(id: '1', sudahIsi: true, kondisiBaik: true),
        unit(id: '2', sudahIsi: true, kondisiBaik: true),
        unit(id: '3', sudahIsi: true, kondisiBaik: false),
        unit(id: '4', sudahIsi: false),
        unit(id: '5', sudahIsi: false),
      ];

      final summary = checklistSummary(items);

      expect(summary.total, 5);
      expect(summary.checked, 3);
      expect(summary.menunggu, 2);
      expect(summary.bermasalah, 1);
      expect(summary.progressRatio, closeTo(0.6, 0.001));
    });

    test('progressRatio 0 saat daftar kosong', () {
      expect(checklistSummary(const []).progressRatio, 0.0);
    });
  });

  group('unitChecklistStatus', () {
    test('klasifikasi menunggu / selesai / bermasalah', () {
      expect(
        unitChecklistStatus(unit(id: '1', sudahIsi: false)),
        ChecklistUnitStatus.menunggu,
      );
      expect(
        unitChecklistStatus(unit(id: '2', sudahIsi: true, kondisiBaik: true)),
        ChecklistUnitStatus.selesai,
      );
      expect(
        unitChecklistStatus(unit(id: '3', sudahIsi: true, kondisiBaik: false)),
        ChecklistUnitStatus.bermasalah,
      );
    });
  });

  group('applyChecklistFilter', () {
    final items = [
      unit(id: '1', sudahIsi: true, kondisiBaik: true),
      unit(id: '2', sudahIsi: true, kondisiBaik: false),
      unit(id: '3', sudahIsi: false),
    ];

    test('semua', () {
      expect(applyChecklistFilter(items, ChecklistFilterK.semua).length, 3);
    });

    test('belum dicek hanya unit yang belum diisi', () {
      final filtered = applyChecklistFilter(items, ChecklistFilterK.belumDicek);
      expect(filtered.length, 1);
      expect(filtered.first.armadaId, '3');
    });

    test('bermasalah hanya unit sudah dicek dengan kondisi tidak baik', () {
      final filtered = applyChecklistFilter(items, ChecklistFilterK.bermasalah);
      expect(filtered.length, 1);
      expect(filtered.first.armadaId, '2');
    });

    test('selesai hanya unit sudah dicek dan dianggap baik', () {
      final filtered = applyChecklistFilter(items, ChecklistFilterK.selesai);
      expect(filtered.length, 1);
      expect(filtered.first.armadaId, '1');
    });
  });

  group('OdoReading', () {
    test('delta & pemakaian untuk kendaraan', () {
      final reading = OdoReading(previous: 45210, current: 45280);
      expect(reading.delta, closeTo(70, 0.001));
      expect(reading.decreased, isFalse);
      expect(reading.pemakaianLabel(false), '+70 km');
    });

    test('warning ketika ODO turun', () {
      final reading = OdoReading(previous: 45280, current: 45100);
      expect(reading.decreased, isTrue);
      expect(reading.pemakaianLabel(false), '+180 km');
    });

    test('jam operasional memakai satuan jam', () {
      final reading = OdoReading(previous: 128.5, current: 6.5);
      expect(reading.decreased, isTrue);
      expect(reading.pemakaianLabel(true), '+122 jam');
    });

    test('tanpa nilai tidak menampilkan delta', () {
      final reading = OdoReading(previous: 100, current: null);
      expect(reading.hasBoth, isFalse);
      expect(reading.pemakaianLabel(false), isNull);
    });
  });

  group('ChecklistItemDraft.toPayload', () {
    test('item baik memetakan baik=true dan status=baik', () {
      final payload = ChecklistItemDraft(label: 'Ban').toPayload();

      expect(payload['label'], 'Ban');
      expect(payload['baik'], isTrue);
      expect(payload['status'], 'baik');
      expect(payload.containsKey('catatan'), isFalse);
      expect(payload.containsKey('has_foto'), isFalse);
    });

    test('item rusak memetakan baik=false, status & catatan & foto', () {
      final payload = ChecklistItemDraft(
        label: 'Rem',
        level: ChecklistItemLevel.rusak,
        catatan: 'Rem tidak pakem',
        photoPath: '/tmp/foto-rem.jpg',
      ).toPayload();

      expect(payload['baik'], isFalse);
      expect(payload['status'], 'rusak');
      expect(payload['catatan'], 'Rem tidak pakem');
      expect(payload['has_foto'], isTrue);
    });

    test('perlu perhatian tetap kondisi tidak baik (business rule), status utuh', () {
      final payload = ChecklistItemDraft(
        label: 'Lampu',
        level: ChecklistItemLevel.perluPerhatian,
      ).toPayload();

      expect(payload['baik'], isFalse);
      expect(payload['status'], 'perlu_perhatian');
    });
  });
}