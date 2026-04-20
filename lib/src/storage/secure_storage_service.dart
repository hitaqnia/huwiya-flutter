import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../exceptions/huwiya_exceptions.dart';
import '../models/auth_token.dart';

class SecureStorageService {
  static const _keyAccessToken = 'huwiya_access_token';
  static const _keyRefreshToken = 'huwiya_refresh_token';
  static const _keyExpiresAt = 'huwiya_expires_at';

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const _iOSOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  final FlutterSecureStorage _storage;

  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: _androidOptions,
        iOptions: _iOSOptions,
      );

  Future<void> saveTokens(AuthToken token) async {
    try {
      await Future.wait([
        _storage.write(
          key: _keyAccessToken,
          value: token.accessToken,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
        _storage.write(
          key: _keyRefreshToken,
          value: token.refreshToken,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
        _storage.write(
          key: _keyExpiresAt,
          value: token.expiresAt.toIso8601String(),
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
      ]);
    } catch (e) {
      throw HuwiyaStorageException('Failed to save tokens', cause: e);
    }
  }

  Future<AuthToken?> readTokens() async {
    try {
      final results = await Future.wait([
        _storage.read(
          key: _keyAccessToken,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
        _storage.read(
          key: _keyRefreshToken,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
        _storage.read(
          key: _keyExpiresAt,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
      ]);

      final accessToken = results[0];
      final refreshToken = results[1];
      final expiresAtStr = results[2];

      if (accessToken == null || refreshToken == null || expiresAtStr == null) {
        return null;
      }

      final expiresAt = DateTime.parse(expiresAtStr);
      return AuthToken(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
      );
    } catch (e) {
      throw HuwiyaStorageException('Failed to read tokens', cause: e);
    }
  }

  Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(
          key: _keyAccessToken,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
        _storage.delete(
          key: _keyRefreshToken,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
        _storage.delete(
          key: _keyExpiresAt,
          aOptions: _androidOptions,
          iOptions: _iOSOptions,
        ),
      ]);
    } catch (e) {
      throw HuwiyaStorageException('Failed to clear tokens', cause: e);
    }
  }
}
