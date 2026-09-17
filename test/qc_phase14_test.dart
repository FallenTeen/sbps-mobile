import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:sbps_mobile/features/qc/models/qc_sample.dart';
import 'package:sbps_mobile/features/qc/qc_home_screen.dart';
import 'package:sbps_mobile/features/qc/qc_providers.dart';
import 'package:sbps_mobile/features/qc/qc_rules.dart';

QcSample _sample({
  String id = 's1',
  String status = 'menunggu_hasil',
  String jenisUji = 'slump_test',
  double? nilaiSlump,
  double? hasilUjiTekan,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? sessionId,
  String? produkNama,
  String? mesinNama,
  String? titikNama,
  DateTime? sesiMulai,
}) {
  return QcSample(
    id: id,
    jenisUji: jenisUji,
    status: status,
    nilaiSlump: nilaiSlump,
    hasilUjiTekan: hasilUjiTekan,
    createdAt: createdAt,
    updatedAt: updatedAt,
    sessionId: sessionId,
    produkNama: produkNama,
    mesinNama: mesinNama,
    titikNama: titikNama,
    sesiMulai: sesiMulai,
  );
}

void main() {
  // Formatter tanggal (id_ID) dipakai QcHomeScreen → ambil sampel jalanan.
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    Intl.defaultLocale = 'id_ID';
  });

  // -------------------------------------------------------------------
  // isTodayFor — filter tanggal murni
  // -------------------------------------------------------------------
  group('isTodayFor', () {
    final now = DateTime(2026, 9, 17, 12, 0, 0);

    test('null bukan hari ini', () {
      expect(isTodayFor(null, now), isFalse);
    });

    test('waktu berbeda pada hari sama → true', () {
      expect(isTodayFor(DateTime(2026, 9, 17, 6, 30), now), isTrue);
    });

    test('kemarin → false', () {
      expect(isTodayFor(DateTime(2026, 9, 16, 23, 59), now), isFalse);
    });

    test('besok → false', () {
      expect(isTodayFor(DateTime(2026, 9, 18, 0, 1), now), isFalse);
    });
  });

  // -------------------------------------------------------------------
  // qcMenunggu / qcTerminal
  // -------------------------------------------------------------------
  group('qcMenunggu / qcTerminal', () {
    test('menunggu_hasil adalah menunggu, bukan terminal', () {
      final s = _sample(status: 'menunggu_hasil');
      expect(qcMenunggu(s), isTrue);
      expect(qcTerminal(s), isFalse);
    });

    test('lolos adalah terminal', () {
      final s = _sample(status: 'lolos');
      expect(qcMenunggu(s), isFalse);
      expect(qcTerminal(s), isTrue);
    });

    test('tidak_lolos adalah terminal', () {
      final s = _sample(status: 'tidak_lolos');
      expect(qcTerminal(s), isTrue);
    });
  });

  // -------------------------------------------------------------------
  // qcWaktuSelesai
  // -------------------------------------------------------------------
  group('qcWaktuSelesai', () {
    test('memakai updated_at bila tersedia', () {
      final s = _sample(
        createdAt: DateTime(2026, 9, 10),
        updatedAt: DateTime(2026, 9, 17),
      );
      expect(qcWaktuSelesai(s), DateTime(2026, 9, 17));
    });

    test('fallback ke created_at bila updated_at null', () {
      final s = _sample(createdAt: DateTime(2026, 9, 10));
      expect(qcWaktuSelesai(s), DateTime(2026, 9, 10));
    });

    test('null bila keduanya kosong', () {
      expect(qcWaktuSelesai(_sample()), isNull);
    });
  });

  // -------------------------------------------------------------------
  // qcJenisUjiLabel
  // -------------------------------------------------------------------
  group('qcJenisUjiLabel', () {
    test('slump_test → Slump Test', () {
      expect(qcJenisUjiLabel('slump_test'), 'Slump Test');
    });

    test('uji_tekan → Uji Tekan', () {
      expect(qcJenisUjiLabel('uji_tekan'), 'Uji Tekan');
    });
  });

  // -------------------------------------------------------------------
  // qcSelesaiHariIni — BENAR-BENAR tanggal, bukan sekadar total
  // -------------------------------------------------------------------
  group('qcSelesaiHariIni', () {
    final now = DateTime(2026, 9, 17);

    test('hanya sampel terminal yang selesai hari ini', () {
      final items = [
        _sample(
          id: 'a',
          status: 'lolos',
          updatedAt: DateTime(2026, 9, 17, 9, 30),
        ),
        _sample(
          id: 'b',
          status: 'tidak_lolos',
          updatedAt: DateTime(2026, 9, 17, 10, 0),
        ),
        _sample(
          id: 'c',
          status: 'lolos',
          updatedAt: DateTime(2026, 9, 16, 23, 59),
        ),
        _sample(
          id: 'd',
          status: 'menunggu_hasil',
          updatedAt: DateTime(2026, 9, 17, 8, 0),
        ),
      ];
      final done = qcSelesaiHariIni(items, now);
      expect(done.map((s) => s.id), ['a', 'b']);
    });

    test('fallback created_at untuk terminal tanpa updated_at', () {
      final items = [
        _sample(id: 'a', status: 'lolos', createdAt: DateTime(2026, 9, 17, 7)),
      ];
      expect(qcSelesaiHariIni(items, now), hasLength(1));
    });

    test('list kosong → kosong', () {
      expect(qcSelesaiHariIni([], now), isEmpty);
    });
  });

  // -------------------------------------------------------------------
  // qcHomeSummary — angka jujur untuk header QC
  // -------------------------------------------------------------------
  group('qcHomeSummary', () {
    test('memeta nilai menunggu & selesai hari ini', () {
      final s = qcHomeSummary(
        menungguPemeriksaan: 2,
        selesaiHariIni: 5,
      );
      expect(s.menungguPemeriksaan, 2);
      expect(s.selesaiHariIni, 5);
    });

    test('nol ketika tidak ada data', () {
      final s = qcHomeSummary(menungguPemeriksaan: 0, selesaiHariIni: 0);
      expect(s.menungguPemeriksaan, 0);
      expect(s.selesaiHariIni, 0);
    });
  });

  // -------------------------------------------------------------------
  // validateNilaiWajib / validateNilaiOpsional — sesuai kontrak
  // -------------------------------------------------------------------
  group('validateNilaiWajib', () {
    test('kosong → wajib', () {
      expect(validateNilaiWajib(''), 'Wajib diisi.');
    });

    test('spasi → wajib', () {
      expect(validateNilaiWajib('   '), 'Wajib diisi.');
    });

    test('non-angka → tidak valid', () {
      expect(validateNilaiWajib('abc'), 'Masukkan angka yang valid.');
    });

    test('negatif → tidak boleh negatif', () {
      expect(validateNilaiWajib('-3'), 'Tidak boleh negatif.');
    });

    test('desimal koma diterima', () {
      expect(validateNilaiWajib('12,5'), isNull);
    });

    test('desimal titik diterima', () {
      expect(validateNilaiWajib('12.5'), isNull);
    });

    test('nol diterima', () {
      expect(validateNilaiWajib('0'), isNull);
    });
  });

  group('validateNilaiOpsional', () {
    test('kosong diperbolehkan', () {
      expect(validateNilaiOpsional(''), isNull);
      expect(validateNilaiOpsional('   '), isNull);
    });

    test('angka valid → null', () {
      expect(validateNilaiOpsional('20'), isNull);
    });

    test('non-angka → error', () {
      expect(validateNilaiOpsional('xx'), isNotNull);
    });

    test('negatif → error', () {
      expect(validateNilaiOpsional('-1'), isNotNull);
    });
  });

  // -------------------------------------------------------------------
  // qcResultNote — tidak menghitung formula kelulusan (backend menentukan)
  // -------------------------------------------------------------------
  group('qcResultNote', () {
    test('tanpa target & actual → hasil akan direkam', () {
      expect(qcResultNote(), contains('Hasil akan direkam'));
    });

    test('target null, actual diisi → actual tercatat', () {
      expect(qcResultNote(actual: 25.0), contains('Actual 25.0 MPa'));
    });

    test('target diisi, actual null → akan dibandingkan sistem', () {
      final n = qcResultNote(target: 20, actual: null);
      expect(n, contains('target 20.0 MPa'));
      expect(n, isNot(contains('lolos/tidak lolos dihitung')));
    });

    test('target & actual diisi → formula dijelaskan sebagai sistem', () {
      final n = qcResultNote(target: 20, actual: 25.0);
      expect(n, contains('Actual 25.0 MPa'));
      expect(n, contains('dihitung sistem (formula QC)'));
    });
  });

  // -------------------------------------------------------------------
  // QcSample.fromJson — menoleransi bentuk produksi (string) dan session
  // (objek) sesuai MobileQcController
  // -------------------------------------------------------------------
  group('QcSample.fromJson', () {
    test('bentuk produksi string (riwayat) parse sessionId & nama', () {
      final s = QcSample.fromJson({
        'id': 'qc-1',
        'jenis_uji': 'slump_test',
        'nilai_slump': 11.5,
        'hasil_uji_tekan': null,
        'status': 'menunggu_hasil',
        'catatan': 'ok',
        'created_at': '2026-09-17T08:00:00',
        'updated_at': '2026-09-17T08:00:00',
        'produksi': {
          'session_id': 'sesi-1',
          'produk': 'Ready Mix',
          'mesin': 'Batching 1',
        },
      });
      expect(s.sessionId, 'sesi-1');
      expect(s.produkNama, 'Ready Mix');
      expect(s.mesinNama, 'Batching 1');
      expect(s.menungguHasil, isTrue);
      expect(s.createdAt, DateTime(2026, 9, 17, 8));
      expect(s.updatedAt, DateTime(2026, 9, 17, 8));
    });

    test('bentuk session objek dengan titik & waktu mulai', () {
      final s = QcSample.fromJson({
        'id': 'qc-2',
        'jenis_uji': 'slump_test',
        'status': 'tidak_lolos',
        'hasil_uji_tekan': 18.0,
        'session': {
          'id': 'sesi-2',
          'mulai': '2026-09-17T07:30:00',
          'produk': {'nama': 'Beton K300'},
          'mesin': {'nama': 'Batching 2'},
          'titik': {'nama': 'Titik B'},
        },
      });
      expect(s.sessionId, 'sesi-2');
      expect(s.produkNama, 'Beton K300');
      expect(s.mesinNama, 'Batching 2');
      expect(s.titikNama, 'Titik B');
      expect(s.sesiMulai, DateTime(2026, 9, 17, 7, 30));
      expect(s.lolos, isFalse);
    });

    test('lolos parsed', () {
      final s = QcSample.fromJson({'id': 'qc-3', 'status': 'lolos'});
      expect(s.lolos, isTrue);
    });
  });

  group('QcRiwayatPage.fromRaw', () {
    test('parse items + pagination', () {
      final page = QcRiwayatPage.fromRaw({
        'items': [
          {'id': 'a', 'status': 'menunggu_hasil'},
          {'id': 'b', 'status': 'lolos'},
        ],
        'pagination': {
          'current_page': 1,
          'last_page': 2,
          'per_page': 2,
          'total': 3,
        },
      });
      expect(page.items, hasLength(2));
      expect(page.total, 3);
      expect(page.currentPage, 1);
      expect(page.lastPage, 2);
      expect(page.hasMore, isTrue);
    });

    test('tidak punya data lain → page default', () {
      final page = QcRiwayatPage.fromRaw(null);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  // -------------------------------------------------------------------
  // Widget: Home QC — queue-first
  // -------------------------------------------------------------------
  group('QcHomeScreen (widget)', () {
    Future<void> pumpHome(
      WidgetTester tester, {
      QcHomeData? data,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            qcHomeProvider.overrideWith(
              (ref) async =>
                  data ??
                  QcHomeData(
                    waitingTotal: 2,
                    waitingQueue: const [],
                    selesaiHariIni: const [],
                  ),
            ),
          ],
          child: const MaterialApp(home: QcHomeScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('menampilkan ringkasan menunggu & selesai hari ini',
        (WidgetTester tester) async {
      final now = DateTime(2026, 9, 17);
      await pumpHome(
        tester,
        data: QcHomeData(
          waitingTotal: 2,
          waitingQueue: [
            _sample(
              id: 'w1',
              sessionId: 's1',
              produkNama: 'Ready Mix',
              mesinNama: 'Batching 1',
              titikNama: 'Titik A',
              sesiMulai: now,
            ),
            _sample(
              id: 'w2',
              sessionId: 's2',
              produkNama: 'Beton K300',
              mesinNama: 'Batching 2',
              titikNama: 'Titik B',
              sesiMulai: now,
            ),
          ],
          selesaiHariIni: [
            for (var i = 0; i < 5; i++)
              _sample(id: 'd$i', status: 'lolos', updatedAt: now),
          ],
        ),
      );

      expect(find.text('2 Menunggu Pemeriksaan'), findsOneWidget);
      expect(find.text('5 Selesai Hari Ini'), findsOneWidget);
      expect(find.text('Antrian Pemeriksaan'), findsOneWidget);
      expect(find.text('Ready Mix — Batching 1'), findsOneWidget);
      expect(find.text('Beton K300 — Batching 2'), findsOneWidget);
      expect(find.textContaining('Titik A'), findsOneWidget);
      expect(find.textContaining('Titik B'), findsOneWidget);
      expect(find.text('Menunggu Uji Tekan'), findsNWidgets(2));
    });

    testWidgets('antrian kosong → empty state bermakna',
        (WidgetTester tester) async {
      await pumpHome(
        tester,
        data: const QcHomeData(
          waitingTotal: 0,
          waitingQueue: [],
          selesaiHariIni: [],
        ),
      );
      expect(find.text('Tidak Ada Pemeriksaan Menunggu'), findsOneWidget);
    });

    testWidgets('tap item antrian membuka sheet dengan context produksi',
        (WidgetTester tester) async {
      final now = DateTime(2026, 9, 17, 8, 30);
      await pumpHome(
        tester,
        data: QcHomeData(
          waitingTotal: 1,
          waitingQueue: [
            _sample(
              id: 'w1',
              sessionId: 's1',
              produkNama: 'Ready Mix',
              mesinNama: 'Batching 1',
              titikNama: 'Titik A',
              sesiMulai: now,
            ),
          ],
          selesaiHariIni: const [],
        ),
      );

      await tester.tap(find.text('Ready Mix — Batching 1'));
      await tester.pumpAndSettle();

      expect(find.text('Catat Uji Tekan'), findsOneWidget);
      expect(find.text('Sedang Diperiksa'), findsOneWidget);
      expect(find.text('Ready Mix'), findsOneWidget);
      expect(find.text('Titik A'), findsOneWidget);
    });
  });
}