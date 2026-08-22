import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// HTTP client minimal untuk endpoint /api/mobile/*.
///
/// Endpoint mobile mewajibkan header device (lihat docs/api-mobile.md).
/// Header Authorization diisi setelah user login (Bearer token Sanctum).
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'X-Device-Type': 'android',
        'X-Device-Name': 'unknown',
      };

  Uri _uri(String path) =>
      Uri.parse('${AppConfig.apiBaseUrl}${path.startsWith('/') ? '' : '/'}$path');

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _client.get(_uri(path), headers: _headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? bearerToken,
  }) async {
    final headers = {..._headers, 'Content-Type': 'application/json'};
    if (bearerToken != null) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    final response = await _client.post(
      _uri(path),
      headers: headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Format respons tidak valid.', statusCode: response.statusCode);
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        (decoded['message'] as String?) ?? 'Terjadi kesalahan (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  void close() => _client.close();
}
