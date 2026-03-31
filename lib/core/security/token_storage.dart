import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_constants.dart';

class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: AppConstants.tokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
  }

  static Future<String?> readAccessToken() {
    return _storage.read(key: AppConstants.tokenKey);
  }

  static Future<String?> readRefreshToken() {
    return _storage.read(key: AppConstants.refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
  }
}
