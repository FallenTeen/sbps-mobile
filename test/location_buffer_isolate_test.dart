import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:sbps_mobile/features/tracking/location_buffer_service.dart';
import 'package:sbps_mobile/features/tracking/models.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('lb_iso');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    final box = await Hive.openBox<String>('tracking_buffer');
    await box.clear();
  });

  tearDown(() async {
    try {
      final box = Hive.box<String>('tracking_buffer');
      await box.clear();
    } catch (_) {}
  });

  TrackPoint pt(String id, DateTime ts) => TrackPoint(
        lat: 1.0,
        lng: 2.0,
        timestamp: ts,
      );

  group('appendPointIsolate', () {
    test('menambah titik dan persist ke Hive', () async {
      await LocationBufferService.appendPointIsolate(
        lat: 10.0,
        lng: 20.0,
        timestamp: DateTime.now(),
      );
      final snap = await LocationBufferService.snapshotIsolate();
      expect(snap, hasLength(1));
      expect(snap.first.lat, 10.0);
      expect(snap.first.lng, 20.0);
    });
  });

  group('pending batch isolate', () {
    test('save/read/clear roundtrip', () async {
      final now = DateTime.now();
      final p = pt('a', now);
      await LocationBufferService.savePendingBatchIsolate('batch-1', [p]);
      final pending = await LocationBufferService.readPendingBatchIsolate();
      expect(pending, isNotNull);
      expect(pending!.batchId, 'batch-1');
      expect(pending.points, hasLength(1));

      await LocationBufferService.clearPendingBatchIsolate();
      final after = await LocationBufferService.readPendingBatchIsolate();
      expect(after, isNull);
    });

    test('readPendingBatchIsolate menghapus data korup', () async {
      final box = await Hive.openBox<String>('tracking_buffer');
      await box.put('pending_batch', '{bad json');
      final pending = await LocationBufferService.readPendingBatchIsolate();
      expect(pending, isNull);
      expect(box.get('pending_batch'), isNull);
    });
  });

  group('snapshotIsolate', () {
    test('mengembalikan semua titik', () async {
      await LocationBufferService.appendPointIsolate(
        lat: 1.0,
        lng: 2.0,
        timestamp: DateTime.now(),
      );
      await LocationBufferService.appendPointIsolate(
        lat: 3.0,
        lng: 4.0,
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
      );
      final snap = await LocationBufferService.snapshotIsolate();
      expect(snap, hasLength(2));
    });

    test('snapshotIsolate data korup -> kosong', () async {
      final box = await Hive.openBox<String>('tracking_buffer');
      await box.put('points', 'not json');
      final snap = await LocationBufferService.snapshotIsolate();
      expect(snap, isEmpty);
    });
  });

  group('removeByIdsIsolate', () {
    test('menghapus titik terkirim', () async {
      await LocationBufferService.appendPointIsolate(
        lat: 1.0,
        lng: 2.0,
        timestamp: DateTime.now(),
      );
      final snap = await LocationBufferService.snapshotIsolate();
      final id = snap.first.id;
      await LocationBufferService.removeByIdsIsolate({id});
      final after = await LocationBufferService.snapshotIsolate();
      expect(after, isEmpty);
    });
  });

  group('pruneStaleIsolate', () {
    test('membuang titik kemarin', () async {
      final box = await Hive.openBox<String>('tracking_buffer');
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await box.put(
        'points',
        '[{"lat":9.0,"lng":9.0,"timestamp":"${yesterday.toLocal().toIso8601String()}"}]',
      );

      await LocationBufferService.pruneStaleIsolate();
      final snap = await LocationBufferService.snapshotIsolate();
      expect(snap, isEmpty);
    });

    test('membuang pending batch yang semua titiknya kemarin', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final p = TrackPoint(lat: 1.0, lng: 2.0, timestamp: yesterday);
      await LocationBufferService.savePendingBatchIsolate('b', [p]);
      await LocationBufferService.pruneStaleIsolate();
      final pending = await LocationBufferService.readPendingBatchIsolate();
      expect(pending, isNull);
    });

    test('mempertahankan pending batch yang masih hari ini', () async {
      final now = DateTime.now();
      final p = TrackPoint(lat: 1.0, lng: 2.0, timestamp: now);
      await LocationBufferService.savePendingBatchIsolate('b2', [p]);
      await LocationBufferService.pruneStaleIsolate();
      final pending = await LocationBufferService.readPendingBatchIsolate();
      expect(pending, isNotNull);
      expect(pending!.batchId, 'b2');
    });
  });

  group('flush lock', () {
    test('acquire pertama sukses, kedua gagal dalam TTL', () async {
      final first = await LocationBufferService.tryAcquireFlushLock();
      expect(first, isTrue);
      final second = await LocationBufferService.tryAcquireFlushLock();
      expect(second, isFalse);
    });

    test('release memungkinkan acquire ulang', () async {
      await LocationBufferService.tryAcquireFlushLock();
      await LocationBufferService.releaseFlushLock();
      final again = await LocationBufferService.tryAcquireFlushLock();
      expect(again, isTrue);
    });
  });
}
