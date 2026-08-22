import '../../core/api_client.dart';
import '../../core/api_response.dart';
import '../../core/storage/token_storage.dart';
import 'models/user.dart';

/// Repository auth: POST /login, /register, /logout, GET /user
/// (docs/api-mobile.md §5). Dipakai bersama App 1 & App 2 (modul shared).
class AuthRepository {
  AuthRepository({required ApiClient api, required TokenStorage storage})
      : _api = api,
        _storage = storage;

  final ApiClient _api;
  final TokenStorage _storage;

  /// Login sukses → token tersimpan, user dikembalikan.
  ///
  /// Error yang mungkin:
  /// - 401 kredensial salah (pesan dari server)
  /// - 403 akun dinonaktifkan (is_active = false)
  /// - 429 rate limit login (5 percobaan/menit per email+IP)
  Future<User> login({
    required String email,
    required String password,
    String? deviceName,
    String? deviceToken,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/login',
      body: {
        'email': email,
        'password': password,
        'device_name': ?deviceName,
        'device_token': ?deviceToken,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
    _ensureSuccess(res);

    final data = res.data!;
    await _storage.saveToken(data['token']?.toString() ?? '');
    return User.fromJson(
      Map<String, dynamic>.from((data['user'] ?? <String, dynamic>{}) as Map),
    );
  }

  /// Registrasi akun baru. Role default backend: `SDM Lapangan Kondisional`.
  Future<User> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? role,
    String? deviceName,
    String? deviceToken,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (role != null && role.isNotEmpty) 'role': role,
        'device_name': ?deviceName,
        'device_token': ?deviceToken,
      },
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
    _ensureSuccess(res);

    final data = res.data!;
    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await _storage.saveToken(token);
    }
    return User.fromJson(
      Map<String, dynamic>.from((data['user'] ?? <String, dynamic>{}) as Map),
    );
  }

  /// Data user aktif — objek user LANGSUNG di `data` (bukan data.user).
  Future<User> getCurrentUser() async {
    final res = await _api.get<Map<String, dynamic>>(
      '/user',
      parse: (raw) => Map<String, dynamic>.from(raw as Map),
    );
    _ensureSuccess(res);
    return User.fromJson(res.data!);
  }

  /// Logout: cabut token server (best-effort) lalu hapus token lokal.
  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } on ApiException catch (e) {
      // Token sudah invalid di server pun tetap anggap logout sukses.
      if (e.statusCode != 401) rethrow;
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    await _storage.deleteToken();
    await _storage.deleteActiveRole();
  }

  void _ensureSuccess(ApiResponse<dynamic> res) {
    if (!res.isSuccess) throw ApiException(res.message);
  }
}
