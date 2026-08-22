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

/// HTTP client untuk endpoint /api/mobile/*.
///
/// Endpoint mobile mewajibkan header device (lihat docs/api-mobile.md bagian
/// 1) — dikirim sebagai header default di setiap request. Interceptor auth
/// (Bearer token, device info asli, X-Active-Role) menyusul di Fase A1.2.
class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? _buildDio();

  final Dio _dio;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          // Backend hanya menolak jika KEDUANYA kosong; nilai asli dari
          // device_info_plus diisi lewat interceptor di Fase A1.2.
          'X-Device-Type': 'android',
          'X-Device-Name': 'unknown',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

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
    return _httpError(response);
  }

  Map<String, List<String>>? _parseErrors(Object? raw) {
    if (raw is! Map) return null;
    return raw.map((key, value) => MapEntry(
          key.toString(),
          value is List ? value.map((e) => e.toString()).toList() : [value.toString()],
        ));
  }

  void close() => _dio.close();
}
