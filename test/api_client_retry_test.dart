import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbps_mobile/core/api_client.dart';

/// Mengunci perbaikan retry multipart: Dio melarang memakai ulang `FormData`
/// yang sudah di-finalize, sehingga percobaan ulang WAJIB memakai
/// `FormData.clone()`. Sebelum perbaikan, hiccup jaringan singkat pada request
/// berfoto membuat retry melempar `StateError` → outbox menandai
/// "menunggu sinkronisasi" padahal perangkat sedang online.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('api_retry');
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  File makeFile() =>
      File('${tempDir.path}\\foto_${DateTime.now().microsecondsSinceEpoch}.jpg')
        ..writeAsStringSync('foto-bytes');

  test('retry jaringan → body multipart dikirim ulang (FormData.clone)', () async {
    final file = makeFile();
    final adapter = _FlakyAdapter(failuresBeforeSuccess: 1);
    final client = ApiClient(dio: ApiClient.buildBaseDio()..httpClientAdapter = adapter);

    final res = await client.postMultipart<Object?>(
      '/armada/checklist/awal',
      fields: const {'armada_id': '1'},
      files: [MultipartFileSpec('foto', file.path)],
      headers: const {'Idempotency-Key': 'idem-1'},
    );

    expect(res.status, 'success');
    expect(adapter.calls, 2, reason: 'gagal sekali (network) lalu retry sukses');
    expect(adapter.paths, ['/armada/checklist/awal', '/armada/checklist/awal']);
  });

  test('429 → body multipart dikirim ulang via intercept 429', () async {
    final file = makeFile();
    final adapter = _FlakyAdapter(
      failuresBeforeSuccess: 1,
      failStatus: 429,
      retryAfter: '0',
    );
    final client = ApiClient(dio: ApiClient.buildBaseDio()..httpClientAdapter = adapter);

    final res = await client.postMultipart<Object?>(
      '/armada/pengisian-solar',
      fields: const {'armada_id': '2'},
      files: [MultipartFileSpec('foto', file.path)],
      headers: const {'Idempotency-Key': 'idem-2'},
    );

    expect(res.status, 'success');
    expect(adapter.calls, 2, reason: '429 sekali lalu retry sukses');
  });
}

/// Adapter palsu: `failuresBeforeSuccess` panggilan pertama gagal — sebagai
/// network error (default) atau HTTP `failStatus` — lalu sukses.
class _FlakyAdapter implements HttpClientAdapter {
  _FlakyAdapter({
    required this.failuresBeforeSuccess,
    this.failStatus,
    this.retryAfter,
  });

  int failuresBeforeSuccess;
  final int? failStatus;
  final String? retryAfter;

  int calls = 0;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    paths.add(options.path);

    if (calls <= failuresBeforeSuccess) {
      if (failStatus != null) {
        return ResponseBody.fromString(
          '{"status":"error","message":"Too Many Requests"}',
          failStatus!,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            if (retryAfter != null) 'retry-after': [retryAfter!],
          },
        );
      }
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'simulasi jaringan putus',
      );
    }

    // Konsumsi body agar stream multipart tidak menggantung.
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    return ResponseBody.fromString(
      '{"status":"success","message":"ok","data":null}',
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
