import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/huwiya_config.dart';
import '../exceptions/huwiya_exceptions.dart';
import '../models/auth_token.dart';
import '../models/huwiya_user.dart';

class TokenService {
  final Dio _dio;
  final HuwiyaConfig _config;

  TokenService({required Dio dio, required HuwiyaConfig config})
    : _dio = dio,
      _config = config;

  Future<({AuthToken token, HuwiyaUser user})> exchange({
    required String code,
    required String codeVerifier,
  }) async {
    final Response response;
    try {
      response = await _dio.post(
        '/oauth/token',
        data: {
          'grant_type': 'authorization_code',
          'client_id': _config.clientId,
          'redirect_uri': _config.redirectUri,
          'code': code,
          'code_verifier': codeVerifier,
        },
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }

    final token = AuthToken.fromJson(response.data as Map<String, dynamic>);
    final user = validateClaims(token.accessToken);
    return (token: token, user: user);
  }

  HuwiyaUser validateClaims(String accessToken) {
    final Map<String, dynamic> claims;
    try {
      final parts = accessToken.split('.');
      if (parts.length < 2) {
        throw HuwiyaClaimsException(
          claim: 'structure',
          reason: 'Not a valid JWT',
        );
      }
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      claims = jsonDecode(payload) as Map<String, dynamic>;
    } on HuwiyaClaimsException {
      rethrow;
    } catch (e) {
      throw HuwiyaClaimsException(
        claim: 'decode',
        reason: 'Failed to decode JWT payload: $e',
      );
    }

    _checkString(
      claims,
      'id',
      extra: (v) {
        if (v.length != 26) {
          throw HuwiyaClaimsException(
            claim: 'id',
            reason: 'Expected 26 chars (ULID), got ${v.length}',
          );
        }
      },
    );
    _checkString(claims, 'name');
    _checkString(claims, 'locale');
    _checkString(claims, 'zoneinfo');
    _checkString(claims, 'theme');

    final rawScopes = claims['scopes'];
    if (rawScopes != null) {
      if (rawScopes is! List) {
        throw HuwiyaClaimsException(claim: 'scopes', reason: 'Expected a List');
      }
      if (rawScopes.any((s) => s is! String)) {
        throw HuwiyaClaimsException(
          claim: 'scopes',
          reason: 'All elements must be strings',
        );
      }
    }

    final iss = claims['iss'];
    if (iss != null && iss != _config.baseUrl) {
      throw HuwiyaClaimsException(
        claim: 'iss',
        reason: 'Expected "${_config.baseUrl}", got "$iss"',
      );
    }

    final aud = claims['aud'];
    if (aud != null && aud != _config.projectId) {
      throw HuwiyaClaimsException(
        claim: 'aud',
        reason: 'Expected "${_config.projectId}", got "$aud"',
      );
    }

    final tolerance = _config.clockSkewTolerance;

    final exp = claims['exp'];
    if (exp != null) {
      final expTime = DateTime.fromMillisecondsSinceEpoch(
        (exp as num).toInt() * 1000,
      );
      if (expTime.isBefore(DateTime.now().subtract(tolerance))) {
        throw HuwiyaClaimsException(
          claim: 'exp',
          reason: 'Token has expired (exp: $expTime)',
        );
      }
    }

    // `iat` in the future is almost always a wrong *device* clock rather than a
    // security issue, so it only fails the token when explicitly opted into via
    // [HuwiyaConfig.validateIssuedAt]. The grace window is [clockSkewTolerance].
    if (_config.validateIssuedAt) {
      final iat = claims['iat'];
      if (iat != null) {
        final iatTime = DateTime.fromMillisecondsSinceEpoch(
          (iat as num).toInt() * 1000,
        );
        if (iatTime.isAfter(DateTime.now().add(tolerance))) {
          throw HuwiyaClaimsException(
            claim: 'iat',
            reason: 'iat is in the future (iat: $iatTime)',
          );
        }
      }
    }

    return HuwiyaUser.fromClaims(claims);
  }

  void _checkString(
    Map<String, dynamic> claims,
    String key, {
    void Function(String value)? extra,
  }) {
    final val = claims[key];
    if (val == null) {
      throw HuwiyaClaimsException(claim: key, reason: 'Missing claim');
    }
    if (val is! String) {
      throw HuwiyaClaimsException(
        claim: key,
        reason: 'Expected String, got ${val.runtimeType}',
      );
    }
    if (val.isEmpty) {
      throw HuwiyaClaimsException(claim: key, reason: 'Must be non-empty');
    }
    extra?.call(val);
  }

  Never _handleDioError(DioException e) {
    final response = e.response;
    if (response != null) {
      final data = response.data;
      if (data is Map<String, dynamic>) {
        throw TokenErrorResponseException(
          data['error']?.toString() ?? 'unknown_error',
          data['error_description']?.toString(),
        );
      }
    }
    throw HuwiyaTokenException('Token request failed', cause: e);
  }
}
