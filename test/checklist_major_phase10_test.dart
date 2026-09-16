import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/armada/armada_monitoring.dart';
import 'package:sbps_mobile/features/armada/checklist_major_model.dart';
import 'package:sbps_mobile/features/armada/models/servis_armada.dart';

ServisArmada _servis(String status, {String armadaId = 'a1'}) {
  return ServisArmada(
    id: 's-$status',
    armadaId: armadaId,
    platNomor: 'B 1234 CD',
    tanggalAjuan: '2026-09-01',
    status: status,
    keluhan: 'Mesin berisik',
  );
}

void main() {
  group('Checklist Major — item & status', () {
    test('defaultMajorChecklistItems membuat 10 item belum dinilai', () {
      final items = defaultMajorChecklistItems();
      expect(items.length, 10);
      expect(items.map((i) => i.index), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(items.every((i) => i.status == MajorChecklistStatus.belum), isTrue);
    });

    test('wire status PERSIS sesuai API', () {
      expect(MajorChecklistStatus.baik.wire, 'baik');
      expect(MajorChecklistStatus.rusakRingan.wire, 'rusak_ringan');
      expect(MajorChecklistStatus.rusakBerat.wire, 'rusak_berat');
      expect(MajorChecklistStatus.belum.wire, isEmpty);
    });

    test('toPayload hanya berisi label + status', () {
      final p = const MajorChecklistItem(
        index: 1,
        label: 'Rem',
        status: MajorChecklistStatus.rusakRingan,
      ).toPayload();
      expect(p['label'], 'Rem');
      expect(p['status'], 'rusak_ringan');
      expect(p.containsKey('photo_index'), isFalse);
    });

    test('needsEvidence true bila rusak, false bila baik/belum', () {
      expect(
        const MajorChecklistItem(
          index: 1,
          label: 'A',
          status: MajorChecklistStatus.baik,
        ).needsEvidence,
        isFalse,
      );
      expect(
        const MajorChecklistItem(
          index: 1,
          label: 'A',
          status: MajorChecklistStatus.rusakBerat,
        ).needsEvidence,
        isTrue,
      );
    });
  });

  group('Progress & ringkasan', () {
    List<MajorChecklistItem> itemsWith(List<MajorChecklistStatus> statuses) {
      final base = defaultMajorChecklistItems();
      return [
        for (var i = 0; i < statuses.length; i++)
          base[i].copyWith(status: statuses[i]),
      ];
    }

    test('majorAssessedCount menghitung yang sudah dinilai', () {
      final items = itemsWith([
        MajorChecklistStatus.baik,
        MajorChecklistStatus.belum,
        MajorChecklistStatus.rusakRingan,
        MajorChecklistStatus.belum,
      ]);
      expect(majorAssessedCount(items), 2);
    });

    test('majorAllAssessed butuh semua item dinilai', () {
      expect(
        majorAllAssessed(itemsWith([for (var i = 0; i < 10; i++) MajorChecklistStatus.baik])),
        isTrue,
      );
      expect(
        majorAllAssessed(itemsWith([
          MajorChecklistStatus.baik,
          MajorChecklistStatus.belum,
          for (var i = 0; i < 8; i++) MajorChecklistStatus.baik,
        ])),
        isFalse,
      );
      expect(majorAllAssessed(const []), isFalse);
    });

    test('majorSummaryOf menghitung Baik/Ringan/Berat', () {
      final items = itemsWith([
        MajorChecklistStatus.baik,
        MajorChecklistStatus.rusakRingan,
        MajorChecklistStatus.baik,
        MajorChecklistStatus.rusakBerat,
        MajorChecklistStatus.belum,
      ]);
      final s = majorSummaryOf(items);
      expect(s.baik, 2);
      expect(s.rusakRingan, 1);
      expect(s.rusakBerat, 1);
      expect(s.totalAssessed, 4);
      expect(s.allBaik, isFalse);
      expect(s.line, '2 Baik • 1 Rusak Ringan • 1 Rusak Berat');
    });

    test('majorSummaryOf.allBaik true bila semua baik', () {
      final items = itemsWith([for (var i = 0; i < 10; i++) MajorChecklistStatus.baik]);
      expect(majorSummaryOf(items).allBaik, isTrue);
    });
  });

  group('Bukti foto & kelayakan submit', () {
    List<MajorChecklistItem> assessed() {
      final base = defaultMajorChecklistItems();
      return [
        for (var i = 0; i < base.length; i++)
          base[i].copyWith(
            status: i % 3 == 0
                ? MajorChecklistStatus.baik
                : (i % 3 == 1
                      ? MajorChecklistStatus.rusakRingan
                      : MajorChecklistStatus.rusakBerat),
          ),
      ];
    }

    test('majorEvidenceComplete butuh foto di setiap item rusak', () {
      var items = assessed();
      expect(majorEvidenceComplete(items), isFalse);

      items = [
        for (final i in items)
          if (i.needsEvidence) i.copyWith(photoPath: '/tmp/photo.jpg') else i,
      ];
      expect(majorEvidenceComplete(items), isTrue);
    });

    test('majorCanSubmit = semua dinilai + bukti lengkap', () {
      final incomplete = [for (final i in assessed()) i.copyWith(status: MajorChecklistStatus.belum)];
      expect(majorCanSubmit(incomplete), isFalse);

      final noPhoto = assessed();
      expect(majorCanSubmit(noPhoto), isFalse);

      final ready = [
        for (final i in assessed())
          if (i.needsEvidence) i.copyWith(photoPath: '/tmp/photo.jpg') else i,
      ];
      expect(majorCanSubmit(ready), isTrue);
    });
  });

  group('Snapshot berangkat → bandingan kembali', () {
    test('snapshot roundtrip JSON mempertahankan data', () {
      final snap = MajorChecklistSnapshot(
        armadaId: 'a1',
        tanggal: '2026-09-10T08:00:00',
        items: [
          (label: 'Rem', status: MajorChecklistStatus.baik),
          (label: 'Ban', status: MajorChecklistStatus.rusakBerat),
        ],
      );
      final decoded = MajorChecklistSnapshot.fromJson(snap.toJson());
      expect(decoded.armadaId, 'a1');
      expect(decoded.tanggal, '2026-09-10T08:00:00');
      expect(decoded.items.length, 2);
      expect(decoded.statusFor('Rem'), MajorChecklistStatus.baik);
      expect(decoded.statusFor('Tidak Ada'), isNull);
    });

    test('compareReturnToBerangkat menandai perubahan yang lebih buruk', () {
      final base = defaultMajorChecklistItems();
      final kini = [
        for (var i = 0; i < base.length; i++)
          base[i].copyWith(
            status: base[i].label == 'Rem'
                ? MajorChecklistStatus.rusakBerat
                : (base[i].label == 'Ban'
                      ? MajorChecklistStatus.baik
                      : MajorChecklistStatus.baik),
          ),
      ];
      final snapshot = MajorChecklistSnapshot(
        armadaId: 'a1',
        tanggal: '2026-09-10T08:00:00',
        items: [
          for (final b in base) (label: b.label, status: MajorChecklistStatus.baik),
        ],
      );

      final comps = compareReturnToBerangkat(kini, snapshot: snapshot);
      final rem = comps.firstWhere((c) => c.label == 'Rem');
      expect(rem.berubah, isTrue);
      expect(rem.berangkat, MajorChecklistStatus.baik);
      expect(rem.kini, MajorChecklistStatus.rusakBerat);

      final ban = comps.firstWhere((c) => c.label == 'Ban');
      expect(ban.berubah, isFalse);
    });

    test('tanpa snapshot, berubah selalu false', () {
      final base = [for (final i in defaultMajorChecklistItems()) i.copyWith(status: MajorChecklistStatus.rusakRingan)];
      final comps = compareReturnToBerangkat(base, snapshot: null);
      expect(comps.every((c) => c.berangkat == null), isTrue);
      expect(comps.every((c) => c.berubah == false), isTrue);
    });
  });

  group('Pemantauan armada — peringatan (data nyata)', () {
    test('unit non-operasional diberi peringatan', () {
      final w = unitWarnings(status: 'rusak');
      expect(w.map((e) => e.key), contains('status'));
      expect(unitWarnings(status: 'aktif'), isEmpty);
      expect(unitWarnings(status: null), isEmpty);
    });

    test('checklist belum diisi → peringatan', () {
      final w = unitWarnings(status: 'aktif', checklistKnown: true, checklistSudahIsi: false);
      expect(w.map((e) => e.key), contains('checklist'));
      final ok = unitWarnings(status: 'aktif', checklistKnown: true, checklistSudahIsi: true);
      expect(ok.map((e) => e.key), isNot(contains('checklist')));
    });

    test('servis diajukan/dikerjakan/disetujui memunculkan peringatan servis', () {
      final w = unitWarnings(
        status: 'aktif',
        servis: [_servis('diajukan'), _servis('disetujui'), _servis('dikerjakan')],
      );
      expect(w.map((e) => e.key), containsAll([
        'servis-diajukan',
        'servis-disetujui',
        'servis-dikerjakan',
      ]));
    });

    test('unit sehat → tanpa peringatan & kebutuhan perhatian false', () {
      final w = unitWarnings(status: 'aktif', checklistSudahIsi: true);
      expect(w, isEmpty);
      expect(unitNeedsAttention(status: 'aktif', checklistSudahIsi: true), isFalse);
    });

    test('servis selesai/ditolak tidak dihitung sebagai peringatan aktif', () {
      final w = unitWarnings(
        status: 'aktif',
        servis: [_servis('selesai'), _servis('ditolak')],
      );
      expect(w, isEmpty);
    });
  });
}