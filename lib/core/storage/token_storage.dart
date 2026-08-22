import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token Sanctum & role aktif via flutter_secure_storage
/// (bukan SharedPreferences — sesuai keputusan Fase A1.2).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kToken = 'auth_token';
  static const _kActiveRole = 'active_role';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> saveToken(String token) => _storage.write(key: _kToken, value: token);

  Future<void> deleteToken() => _storage.delete(key: _kToken);

  Future<String?> readActiveRole() => _storage.read(key: _kActiveRole);

  Future<void> saveActiveRole(String role) =>
      _storage.write(key: _kActiveRole, value: role);

  Future<void> deleteActiveRole() => _storage.delete(key: _kActiveRole);
}
