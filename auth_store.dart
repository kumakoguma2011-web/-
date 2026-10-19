import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStore {
  static const _tokenKey = 'career_ai_access_token';
  static const _userKey = 'career_ai_user_key';
  static const _lastActivityKey = 'career_ai_last_activity_at';
  final _s = const FlutterSecureStorage();

  Future<void> save({required String token, required String userKey}) async {
    await _s.write(key: _tokenKey, value: token);
    await _s.write(key: _userKey, value: userKey);
  }

  Future<String?> readToken() => _s.read(key: _tokenKey);
  Future<String?> readUserKey() => _s.read(key: _userKey);
  Future<String?> readLastActivity() => _s.read(key: _lastActivityKey);

  Future<void> saveLastActivity(DateTime at) =>
      _s.write(key: _lastActivityKey, value: at.toUtc().toIso8601String());

  Future<void> clearToken() async {
    await _s.delete(key: _tokenKey);
    await _s.delete(key: _lastActivityKey);
  }

  Future<void> clearAll() async {
    await Future.wait([
      _s.delete(key: _tokenKey),
      _s.delete(key: _userKey),
      _s.delete(key: _lastActivityKey),
    ]);
  }
}
