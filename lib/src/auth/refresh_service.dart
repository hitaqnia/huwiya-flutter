import 'package:dio/dio.dart';

import '../auth/auth_notifier.dart';
import '../core/huwiya_config.dart';
import '../exceptions/huwiya_exceptions.dart';
import '../models/auth_token.dart';
import '../storage/secure_storage_service.dart';
import 'token_service.dart';

class RefreshService {
  static const _refreshThreshold = Duration(seconds: 60);

  final Dio _dio;
  final HuwiyaConfig _config;
  final SecureStorageService _storage;
  final AuthStateNotifier _notifier;
  final TokenService _tokenService;

  Future<String>? _inflightRefresh;

  RefreshService({
    required Dio dio,
    required HuwiyaConfig config,
    required SecureStorageService storage,
    required AuthStateNotifier notifier,
  }) : _dio = dio,
       _config = config,
       _storage = storage,
       _notifier = notifier,
       _tokenService = TokenService(dio: dio, config: config);

  Future<String> getAccessToken() async {
    final stored = await _storage.readTokens();
    if (stored == null) throw const HuwiyaAuthException('No active session');

    final isNearExpiry = stored.expiresAt.isBefore(
      DateTime.now().add(_refreshThreshold),
    );
    if (!isNearExpiry) return stored.accessToken;

    // Without a refresh token there is nothing to refresh with, so keep using
    // the current access token until it actually expires (callers handle the
    // eventual 401). This happens when the server only issues a refresh token
    // on first consent.
    final refreshToken = stored.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return stored.accessToken;
    }

    _inflightRefresh ??= _doRefresh().whenComplete(
      () => _inflightRefresh = null,
    );
    return _inflightRefresh!;
  }

  Future<String> _doRefresh() async {
    _notifier.setRefreshing();

    final stored = await _storage.readTokens();
    if (stored == null) {
      _notifier.setUnauthenticated();
      throw const HuwiyaAuthException('No active session for refresh');
    }

    final refreshToken = stored.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearAndSignOut();
      throw const HuwiyaAuthException('No refresh token available');
    }

    try {
      final response = await _dio.post(
        '/oauth/token',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _config.clientId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken =
          data['refresh_token'] as String? ?? stored.refreshToken;
      final expiresIn = (data['expires_in'] as num).toInt();

      final user = _tokenService.validateClaims(newAccessToken);

      final newToken = AuthToken(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      );

      await _storage.saveTokens(newToken);
      _notifier.setAuthenticated(user, accessToken: newAccessToken);

      return newAccessToken;
    } on DioException catch (e) {
      await _clearAndSignOut();
      final response = e.response;
      if (response?.data is Map<String, dynamic>) {
        final data = response!.data as Map<String, dynamic>;
        throw TokenErrorResponseException(
          data['error']?.toString() ?? 'unknown_error',
          data['error_description']?.toString(),
        );
      }
      throw HuwiyaTokenException('Token refresh failed', cause: e);
    } on HuwiyaClaimsException {
      await _clearAndSignOut();
      rethrow;
    }
  }

  Future<void> _clearAndSignOut() async {
    await _storage.clearTokens();
    _notifier.setUnauthenticated();
  }

  Future<void> signOut() async {
    _inflightRefresh = null;
    await _storage.clearTokens();
    _notifier.setUnauthenticated();
  }

  void installAuthInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await getAccessToken();
            options.headers['Authorization'] = 'Bearer $token';
          } on HuwiyaAuthException {
            // No active session — proceed without an Authorization header.
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<void> restoreSession() async {
    final stored = await _storage.readTokens();
    if (stored == null) return;

    final isValid = stored.expiresAt.isAfter(
      DateTime.now().add(_refreshThreshold),
    );
    if (isValid) {
      try {
        final user = _tokenService.validateClaims(stored.accessToken);
        _notifier.setAuthenticated(user, accessToken: stored.accessToken);
      } on HuwiyaClaimsException {
        await _clearAndSignOut();
      }
    } else {
      try {
        await _doRefresh();
      } catch (_) {}
    }
  }
}
