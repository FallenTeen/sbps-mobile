import 'dart:io';

import 'package:dio/dio.dart';

import 'api_response.dart';
import 'app_config.dart';

/// Error yang dilempar [ApiClient] untuk semua kondisi gagal (jaringan,
/// HTTP >= 400, format respons tidak valid).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;

  /// Detail error 422 Laravel: `{ "errors": { field: [pesan] } }`.
  final Map<String, List<String>>? errors;

  @override
  String toString() => message;
}

/// Spesifikasi satu file multipart: nama field + path lokal.
class MultipartFileSpec {
  const MultipartFileSpec(this.field, this.path);

  final String field;
  final String path;
}

/// HTTP client untuk endpoint /api/mobile/*.
class ApiClient {
  ApiClient({Dio? dio, this.onUnauthorized}) : _dio = dio ?? buildBaseDio();

  /// Dio dasar (timeout, base URL, header default); dipakai provider untuk
  /// memasang interceptor auth sebelum membuat client.
  static Dio buildBaseDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.requiredApiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
          'X-Device-Type': 'android',
          'X-Device-Name': 'unknown',
        },
        // 429 ditangani _RateLimitInterceptor, bukan error Dio.
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    // Retry transient dulu, baru rate limit.
    dio.interceptors.add(_TransientNetworkRetryInterceptor(dio));
    dio.interceptors.add(_RateLimitInterceptor(dio));
    return dio;
  }

  /// Dipanggil saat 401 dari endpoint terproteksi (token invalid/kadaluarsa).
  void Function()? onUnauthorized;

  /// 401 di sini = kredensial salah, bukan sesi berakhir.
  static const _publicPaths = ['/login', '/register', '/app-version'];

  final Dio _dio;

  /// Akses Dio internal untuk pasang interceptor auth.
  Dio get dio => _dio;

  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) {
    return _send(path, query: query, headers: headers, parse: parse);
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) {
    return _send(
      path,
      method: 'POST',
      body: body,
      query: query,
      headers: headers,
      parse: parse,
    );
  }

  /// POST multipart/form-data (unggah file: `photo`, `photos[]`).
  Future<ApiResponse<T>> postMultipart<T>(
    String path, {
    Map<String, String> fields = const {},
    required List<MultipartFileSpec> files,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    final form = FormData();
    form.fields.addAll(fields.entries);
    for (final spec in files) {
      final fileName = spec.path.split(Platform.pathSeparator).last;
      form.files.add(
        MapEntry(
          spec.field,
          await MultipartFile.fromFile(spec.path, filename: fileName),
        ),
      );
    }
    return _send(
      path,
      method: 'POST',
      body: form,
      headers: headers,
      parse: parse,
    );
  }

  /// DELETE — hapus file upload (docs/api-mobile.md §11.2).
  Future<ApiResponse<T>> delete<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) {
    return _send(
      path,
      method: 'DELETE',
      query: query,
      headers: headers,
      parse: parse,
    );
  }

  Future<ApiResponse<T>> _send<T>(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    T Function(Object? raw)? parse,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, headers: headers),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
    if (response.statusCode == null || response.statusCode! >= 400) {
      throw _httpError(response, method: method);
    }
    final decoded = response.data;
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
        'Format respons tidak valid.',
        statusCode: response.statusCode,
      );
    }
    return ApiResponse.fromJson(decoded, parse: parse);
  }

  /// HTTP >= 400: bisa envelope `{status:"error", message, errors}` maupun
  /// error validasi 422 Laravel `{message, errors}` tanpa wrapper.
  ApiException _httpError(Response<dynamic> response, {String? method}) {
    final data = response.data;
    if (data is Map) {
      final json = Map<String, dynamic>.from(data);
      final serverMsg = json['message'] as String?;
      final errors = _parseErrors(json['errors']);
      final statusMsg = serverMsg ?? 'Terjadi kesalahan';
      final isGet =
          (method ?? response.requestOptions.method).toUpperCase() == 'GET';

      String reason = '';
      if (json['errors'] != null) {
        if (errors != null && errors.containsKey('karyawan')) {
          reason = errors['karyawan']?.join(' ') ?? '';
        } else if (isGet) {
          reason = errors?.values.expand((e) => e).join(' ') ?? '';
        } else {
          reason = 'Validasi gagal: periksa field yang ditandai merah.';
        }
      }

      final action = response.statusCode! >= 500
          ? 'Coba lagi beberapa saat. Jika masih gagal, hubungi admin.'
          : (isGet || (errors != null && errors.containsKey('karyawan'))
              ? 'Hubungi admin atau coba lagi.'
              : 'Periksa kembali data Anda dan coba kirim ulang.');

      final parts = [
        statusMsg,
        if (reason.isNotEmpty && reason != statusMsg) reason,
        action,
      ];

      return ApiException(
        parts.join('\n'),
        statusCode: response.statusCode,
        errors: errors,
      );
    }
    return ApiException(
      'Tidak dapat terhubung ke server\nPeriksa koneksi internet Anda\nCoba lagi atau matikan lalu hidupkan kembali jaringan.',
      statusCode: response.statusCode,
    );
  }

  ApiException _mapDioError(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException(
        'Tidak dapat terhubung ke server\nPeriksa koneksi internet Anda\nCoba lagi atau matikan lalu hidupkan kembali jaringan.',
      );
    }
    if (response.statusCode == 401 && !_isPublic(e.requestOptions.path)) {
      onUnauthorized?.call();
    }
    return _httpError(response, method: e.requestOptions.method);
  }

  bool _isPublic(String path) => _publicPaths.any((p) => path.endsWith(p));

  Map<String, List<String>>? _parseErrors(Object? raw) {
    if (raw is! Map) return null;
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is List
            ? value.map((e) => e.toString()).toList()
            : [value.toString()],
      ),
    );
  }

  void close() => _dio.close();
}

/// Interceptor transient network error (DioException tanpa response):
/// retry 1x dengan delay 750ms sebelum diteruskan ke error handler.
/// Retry aman untuk GET dan POST/PUT/DELETE berasal dari outbox yang sudah
/// memakai Idempotency-Key di header.
class _TransientNetworkRetryInterceptor extends Interceptor {
  _TransientNetworkRetryInterceptor(this._dio);

  final Dio _dio;
  static const _maxRetries = 1;
  static const _retryDelay = Duration(milliseconds: 750);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response != null) {
      handler.next(err);
      return;
    }
    final count =
        (err.requestOptions.extra['_transientRetry'] as int?) ?? 0;
    if (count >= _maxRetries) {
      handler.next(err);
      return;
    }
    await Future<void>.delayed(_retryDelay);
    final opts = _cloneRequestForRetry(err.requestOptions)
      ..extra['_transientRetry'] = count + 1;
    try {
      final retried = await _dio.fetch<dynamic>(opts);
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Interceptor 429 Too Many Requests: parse header `Retry-After` (detik),
/// fallback backoff 1s/2s/4s, maks 3 retry.
class _RateLimitInterceptor extends Interceptor {
  _RateLimitInterceptor(this._dio);

  final Dio _dio;
  static const _maxRetries = 3;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 429) {
      final retryCount =
          (response.requestOptions.extra['_rateLimitRetry'] as int?) ?? 0;
      if (retryCount >= _maxRetries) {
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: 'Rate limit exceeded after $_maxRetries retries.',
          ),
        );
        return;
      }
      _retryAfterDelay(response, retryCount, handler);
      return;
    }
    super.onResponse(response, handler);
  }

  Future<void> _retryAfterDelay(
    Response response,
    int retryCount,
    ResponseInterceptorHandler handler,
  ) async {
    final retryAfterRaw =
        response.headers.value('Retry-After') ??
        response.headers.value('retry-after');
    final retryAfterSeconds = int.tryParse(retryAfterRaw ?? '');
    final delay = retryAfterSeconds != null
        ? Duration(seconds: retryAfterSeconds)
        : Duration(seconds: 1 << retryCount); // 1s, 2s, 4s

    await Future<void>.delayed(delay);

    final opts = _cloneRequestForRetry(response.requestOptions)
      ..extra['_rateLimitRetry'] = retryCount + 1;
    try {
      final retried = await _dio.fetch(opts);
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.reject(e);
    }
  }
}

/// Ulangi [RequestOptions] untuk dikirim ulang; FormData yang sudah
/// di-finalize tidak bisa dipakai ulang, jadi harus [FormData.clone].
RequestOptions _cloneRequestForRetry(RequestOptions opts) {
  final data = opts.data;
  return opts.copyWith(data: data is FormData ? data.clone() : data);
}
