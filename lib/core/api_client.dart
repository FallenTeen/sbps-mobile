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

  /// Detail error validasi Laravel 422: `{ "errors": { field: [pesan] } }`.
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
///
/// Endpoint mobile mewajibkan header device (lihat docs/api-mobile.md bagian
/// 1) — dikirim sebagai header default di setiap request. Interceptor auth
/// (Bearer token, X-Active-Role) dipasang dari luar lewat [dio].
class ApiClient {
  ApiClient({Dio? dio, this.onUnauthorized})
      : _dio = dio ?? buildBaseDio();

  /// Dio dasar dengan timeout, base URL, dan header default — dipakai juga
  /// oleh provider untuk memasang interceptor auth sebelum membuat client.
  static Dio buildBaseDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          // Backend hanya menolak jika KEDUANYA kosong (hasil audit); nilai
          // asli perangkat ditimpa lewat interceptor (Fase A1.2).
          'X-Device-Type': 'android',
          'X-Device-Name': 'unknown',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  /// Dipanggil saat endpoint terproteksi menjawab 401 (token invalid/kadaluarsa)
  /// — dipakai AuthController untuk memaksa logout & redirect ke login.
  void Function()? onUnauthorized;

  /// Endpoint publik: 401 dari sini adalah error kredensial biasa,
  /// bukan sesi berakhir — tidak boleh memicu [onUnauthorized].
  static const _publicPaths = ['/login', '/register', '/app-version'];

  final Dio _dio;

  /// Akses Dio internal untuk pemasangan interceptor auth.
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
    return _send(path, method: 'POST', body: body, query: query, headers: headers, parse: parse);
  }

  /// POST multipart/form-data — dipakai endpoint dengan unggahan file
  /// (presensi check-in/out: `photo`; formulir lapangan: `photos[]`).
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
      form.files.add(MapEntry(
        spec.field,
        await MultipartFile.fromFile(spec.path, filename: fileName),
      ));
    }
    return _send(path, method: 'POST', body: form, headers: headers, parse: parse);
  }

  /// DELETE — dipakai endpoint hapus file upload (docs/api-mobile.md §11.2).
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
      throw _httpError(response);
    }
    final decoded = response.data;
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Format respons tidak valid.',
          statusCode: response.statusCode);
    }
    return ApiResponse.fromJson(decoded, parse: parse);
  }

  /// HTTP >= 400: bisa envelope `{status:"error", message, errors}` maupun
  /// error validasi bawaan Laravel 422 `{message, errors}` tanpa wrapper.
  ApiException _httpError(Response<dynamic> response) {
    final data = response.data;
    if (data is Map) {
      final json = Map<String, dynamic>.from(data);
      return ApiException(
        json['message'] as String? ??
            'Terjadi kesalahan (${response.statusCode}).',
        statusCode: response.statusCode,
        errors: _parseErrors(json['errors']),
      );
    }
    return ApiException('Terjadi kesalahan (${response.statusCode}).',
        statusCode: response.statusCode);
  }

  ApiException _mapDioError(DioException e) {
    final response = e.response;
    if (response == null) {
      return ApiException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    }
    if (response.statusCode == 401 && !_isPublic(e.requestOptions.path)) {
      onUnauthorized?.call();
    }
    return _httpError(response);
  }

  bool _isPublic(String path) =>
      _publicPaths.any((p) => path.endsWith(p));

  Map<String, List<String>>? _parseErrors(Object? raw) {
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry(
          key.toString(),
          value is List ? value.map((e) => e.toString()).toList() : [value.toString()],
        ));
  }

  void close() => _dio.close();
}
