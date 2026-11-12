import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:sbps_mobile/features/tracking/location_buffer_service.dart';
import 'package:sbps_mobile/features/tracking/tracking_isolate_upload.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);
  final Future<ResponseBody> Function(RequestOptions) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _resp(int status, {String body = '{}'}) => ResponseBody(
      Stream.value(const Utf8Encoder().convert(body)),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('upload_iso');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    TrackingIsolateUpload.resetForTest();
    final box = await Hive.openBox<String>('tracking_buffer');
    await box.clear();
    await box.delete('flush_lock');
  });

  tearDown(() async {
    try {
      final box = Hive.box<String>('tracking_buffer');
      await box.clear();
    } catch (_) {}
  });

  Future<void> seedPoint() async {
    await LocationBufferService.appendPointIsolate(
      lat: 1.0,
      lng: 2.0,
      timestamp: DateTime.now(),
    );
  }

  test('tanpa token -> return awal, buffer tidak berubah', () async {
    await seedPoint();
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((_) async => _resp(200));
    await TrackingIsolateUpload.flush(client: dio, token: '', role: '');
    final snap = await LocationBufferService.snapshotIsolate();
    expect(snap, hasLength(1));
  });

  test('buffer kosong -> tidak ada request', () async {
    var called = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((_) async {
      called = true;
      return _resp(200);
    });
    await TrackingIsolateUpload.flush(client: dio, token: 'tok', role: 'Test');
    expect(called, isFalse);
  });

  test('sukses 200 -> buffer kosong & pending cleared', () async {
    await seedPoint();
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((_) async => _resp(200));
    await TrackingIsolateUpload.flush(client: dio, token: 'tok', role: 'Test');
    final snap = await LocationBufferService.snapshotIsolate();
    expect(snap, isEmpty);
    final pending = await LocationBufferService.readPendingBatchIsolate();
    expect(pending, isNull);
  });

  test('422 -> buffer & pending dipertahankan', () async {
    await seedPoint();
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((_) async => _resp(422));
    await TrackingIsolateUpload.flush(client: dio, token: 'tok', role: 'Test');
    final snap = await LocationBufferService.snapshotIsolate();
    expect(snap, hasLength(1));
    final pending = await LocationBufferService.readPendingBatchIsolate();
    expect(pending, isNotNull);
  });

  test('network error -> buffer & pending dipertahankan', () async {
    await seedPoint();
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((_) async {
      throw DioException(
        requestOptions: RequestOptions(path: '/tracking/batch'),
        type: DioExceptionType.connectionError,
      );
    });
    await TrackingIsolateUpload.flush(client: dio, token: 'tok', role: 'Test');
    final snap = await LocationBufferService.snapshotIsolate();
    expect(snap, hasLength(1));
    final pending = await LocationBufferService.readPendingBatchIsolate();
    expect(pending, isNotNull);
  });

  test('pending batch yang ada dipakai ulang (idempotent)', () async {
    await seedPoint();
    final snap = await LocationBufferService.snapshotIsolate();
    await LocationBufferService.savePendingBatchIsolate('fixed-batch', snap);
    final box = Hive.box<String>('tracking_buffer');
    await box.put('points', '[]');

    String? capturedBatch;
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((opts) async {
      final data = opts.data is String
          ? jsonDecode(opts.data as String) as Map<String, dynamic>
          : opts.data as Map<String, dynamic>;
      capturedBatch = data['batch_id'] as String;
      return _resp(200);
    });
    await TrackingIsolateUpload.flush(client: dio, token: 'tok', role: 'Test');
    expect(capturedBatch, 'fixed-batch');
  });

  test('lock mencegah flush paralel', () async {
    await seedPoint();
    await LocationBufferService.tryAcquireFlushLock();
    var called = false;
    final dio = Dio(BaseOptions(baseUrl: 'http://x'));
    dio.httpClientAdapter = _FakeAdapter((_) async {
      called = true;
      return _resp(200);
    });
    await TrackingIsolateUpload.flush(client: dio, token: 'tok', role: 'Test');
    expect(called, isFalse);
    final snap = await LocationBufferService.snapshotIsolate();
    expect(snap, hasLength(1));
    await LocationBufferService.releaseFlushLock();
  });
}
