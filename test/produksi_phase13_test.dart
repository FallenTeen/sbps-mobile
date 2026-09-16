import 'package:flutter_test/flutter_test.dart';

import 'package:sbps_mobile/features/produksi/models/production_session.dart';
import 'package:sbps_mobile/features/produksi/produksi_rules.dart' as rules;

ProductionSession _session({
  String id = 's1',
  String status = 'berjalan',
  double hasilOutput = 0,
}) {
  return ProductionSession(
    id: id,
    mesinId: 'm1',
    mesinNama: 'Mesin A',
    produkId: 'p1',
    produkNama: 'Ready Mix',
    titikId: 't1',
    titikNama: 'Proyek X',
    status: status,
    hasilOutput: hasilOutput,
  );
}

TitikProgressItem _progress({
  String titikId = 't1',
  double totalOutput = 100,
  int jumlahSesi = 3,
}) {
  return TitikProgressItem(
    titikId: titikId,
    titikNama: 'Titik A',
    totalOutput: totalOutput,
    jumlahSesi: jumlahSesi,
  );
}

void main() {
  // -------------------------------------------------------------------
  // formatDurasiSesi
  // -------------------------------------------------------------------
  group('formatDurasiSesi', () {
    test('durasi 0 menghasilkan 0m', () {
      expect(rules.formatDurasiSesi(Duration.zero), '0m');
    });

    test('menit saja tanpa jam', () {
      expect(rules.formatDurasiSesi(const Duration(minutes: 45)), '45m');
    });

    test('jam utuh tanpa sisa menit', () {
      expect(rules.formatDurasiSesi(const Duration(hours: 2)), '2j');
    });

    test('jam dan menit', () {
      expect(
        rules.formatDurasiSesi(const Duration(hours: 1, minutes: 30)),
        '1j 30m',
      );
    });

    test('jam panjang dengan sisa', () {
      expect(
        rules.formatDurasiSesi(const Duration(hours: 5, minutes: 12)),
        '5j 12m',
      );
    });

    test('hanya 1 menit', () {
      expect(rules.formatDurasiSesi(const Duration(minutes: 1)), '1m');
    });
  });

  // -------------------------------------------------------------------
  // sessionStatusLabel
  // -------------------------------------------------------------------
  group('sessionStatusLabel', () {
    test('berjalan', () {
      expect(rules.sessionStatusLabel('berjalan'), 'Berjalan');
    });

    test('selesai', () {
      expect(rules.sessionStatusLabel('selesai'), 'Selesai');
    });

    test('unknown status tetap Berjalan', () {
      expect(rules.sessionStatusLabel('pending'), 'Berjalan');
    });
  });

  // -------------------------------------------------------------------
  // nextActionForSession
  // -------------------------------------------------------------------
  group('nextActionForSession', () {
    test('tanpa waiting QC → slump test', () {
      final label = rules.nextActionForSession(hasWaitingQc: false);
      expect(label, contains('slump test'));
    });

    test('dengan waiting QC → uji tekan', () {
      final label = rules.nextActionForSession(hasWaitingQc: true);
      expect(label, contains('uji tekan'));
    });
  });

  // -------------------------------------------------------------------
  // validateHasilOutput
  // -------------------------------------------------------------------
  group('validateHasilOutput', () {
    test('string kosong mengembalikan error wajib', () {
      expect(rules.validateHasilOutput(''), 'Hasil output wajib diisi.');
    });

    test('spasi saja mengembalikan error wajib', () {
      expect(rules.validateHasilOutput('   '), 'Hasil output wajib diisi.');
    });

    test('teks bukan angka mengembalikan error valid', () {
      expect(rules.validateHasilOutput('abc'), 'Masukkan angka yang valid.');
    });

    test('angka negatif mengembalikan error negatif', () {
      expect(rules.validateHasilOutput('-5'), 'Tidak boleh negatif.');
    });

    test('nol valid', () {
      expect(rules.validateHasilOutput('0'), isNull);
    });

    test('angka positif valid', () {
      expect(rules.validateHasilOutput('123.5'), isNull);
    });

    test('koma didesain menjadi titik', () {
      expect(rules.validateHasilOutput('45,5'), isNull);
    });
  });

  // -------------------------------------------------------------------
  // filterRiwayatByStatus
  // -------------------------------------------------------------------
  group('filterRiwayatByStatus', () {
    final items = [
      _session(id: 's1', status: 'berjalan'),
      _session(id: 's2', status: 'selesai'),
      _session(id: 's3', status: 'berjalan'),
      _session(id: 's4', status: 'selesai'),
    ];

    test('null mengembalikan semua', () {
      expect(rules.filterRiwayatByStatus(items, null).length, 4);
    });

    test('Semua mengembalikan semua', () {
      expect(rules.filterRiwayatByStatus(items, 'Semua').length, 4);
    });

    test('Berjalan hanya mengembalikan sesi berjalan', () {
      final result = rules.filterRiwayatByStatus(items, 'Berjalan');
      expect(result.length, 2);
      expect(result.every((s) => s.berjalan), isTrue);
    });

    test('Selesai hanya mengembalikan sesi selesai', () {
      final result = rules.filterRiwayatByStatus(items, 'Selesai');
      expect(result.length, 2);
      expect(result.every((s) => !s.berjalan), isTrue);
    });

    test('empty string dikembalikan semua', () {
      expect(rules.filterRiwayatByStatus(items, '').length, 4);
    });

    test('status unknown mengembalikan semua (fallback)', () {
      expect(rules.filterRiwayatByStatus(items, 'Dibatalkan').length, 4);
    });
  });

  // -------------------------------------------------------------------
  // produksiHomeSummary
  // -------------------------------------------------------------------
  group('produksiHomeSummary', () {
    test('tanpa data menghasilkan nol semua', () {
      final s = rules.produksiHomeSummary();
      expect(s.totalSesi, 0);
      expect(s.totalOutput, 0);
      expect(s.sesiBerjalan, 0);
      expect(s.sesiMenungguQc, 0);
    });

    test('total sesi = sesi selesai (progress) + sesi berjalan', () {
      final s = rules.produksiHomeSummary(
        sesiAktif: [_session(id: 'a'), _session(id: 'b')],
        progress: [_progress(jumlahSesi: 5), _progress(titikId: 't2', jumlahSesi: 3)],
      );
      expect(s.totalSesi, 10); // 5 + 3 + 2
      expect(s.sesiBerjalan, 2);
    });

    test('total output = jumlah totalOutput dari progress', () {
      final s = rules.produksiHomeSummary(
        progress: [_progress(totalOutput: 100), _progress(titikId: 't2', totalOutput: 250)],
      );
      expect(s.totalOutput, 350.0);
    });

    test('sesiMenungguQc = waitingQcCount', () {
      final s = rules.produksiHomeSummary(waitingQcCount: 3);
      expect(s.sesiMenungguQc, 3);
    });

    test('butuhPerhatian == sesiMenungguQc', () {
      final s = rules.produksiHomeSummary(waitingQcCount: 2);
      expect(s.butuhPerhatian, 2);
    });

    test('kombinasi lengkap', () {
      final s = rules.produksiHomeSummary(
        sesiAktif: [_session(id: 'a'), _session(id: 'b')],
        progress: [_progress(jumlahSesi: 4, totalOutput: 200)],
        waitingQcCount: 1,
      );
      expect(s.totalSesi, 6); // 4 selesai + 2 berjalan
      expect(s.totalOutput, 200.0);
      expect(s.sesiBerjalan, 2);
      expect(s.sesiMenungguQc, 1);
      expect(s.butuhPerhatian, 1);
    });
  });
}