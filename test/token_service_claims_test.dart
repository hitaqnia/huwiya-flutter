import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huwiya_sdk/huwiya_sdk.dart';
import 'package:huwiya_sdk/src/auth/token_service.dart';

/// Builds an unsigned JWT (`header.payload.signature`) whose payload is
/// [claims]. [TokenService.validateClaims] only decodes the payload — it does
/// not verify the signature — so a placeholder signature is fine here.
String _jwt(Map<String, dynamic> claims) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = {'alg': 'RS256', 'typ': 'JWT'};
  return '${seg(header)}.${seg(claims)}.sig';
}

int _epochSeconds(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

Map<String, dynamic> _baseClaims({
  required DateTime iat,
  required DateTime exp,
}) => {
  'id': '01HZY0R8X4ABCDEFGHJKMNPQRS', // 26-char ULID-like
  'name': 'YOUSOF',
  'locale': 'en',
  'zoneinfo': 'Asia/Baghdad',
  'theme': 'system',
  'scopes': <String>[],
  'iat': _epochSeconds(iat),
  'exp': _epochSeconds(exp),
};

TokenService _service({bool validateIssuedAt = false, Duration? tolerance}) {
  final config = HuwiyaConfig(
    baseUrl: 'https://id.example.com',
    projectId: 'proj_123',
    clientId: 'client_abc',
    redirectUri: 'com.example.app://auth/callback',
    validateIssuedAt: validateIssuedAt,
    clockSkewTolerance: tolerance ?? const Duration(minutes: 5),
  );
  return TokenService(dio: Dio(), config: config);
}

void main() {
  group('TokenService.validateClaims — issued-at / clock skew', () {
    test('accepts a token whose iat is far in the future by default', () {
      // Simulates a device clock that lags ~25h behind the server.
      final now = DateTime.now();
      final token = _jwt(
        _baseClaims(
          iat: now.add(const Duration(hours: 25)),
          exp: now.add(const Duration(hours: 25, minutes: 30)),
        ),
      );

      final user = _service().validateClaims(token);
      expect(user.name, 'YOUSOF');
      expect(user.locale, 'en');
    });

    test('rejects a future iat when validateIssuedAt is enabled', () {
      final now = DateTime.now();
      final token = _jwt(
        _baseClaims(
          iat: now.add(const Duration(hours: 25)),
          exp: now.add(const Duration(hours: 25, minutes: 30)),
        ),
      );

      expect(
        () => _service(validateIssuedAt: true).validateClaims(token),
        throwsA(
          isA<HuwiyaClaimsException>().having((e) => e.claim, 'claim', 'iat'),
        ),
      );
    });

    test('tolerates a slightly-expired token within clockSkewTolerance', () {
      final now = DateTime.now();
      final token = _jwt(
        _baseClaims(
          iat: now.subtract(const Duration(minutes: 10)),
          exp: now.subtract(const Duration(minutes: 2)), // within 5-min grace
        ),
      );

      expect(_service().validateClaims(token).name, 'YOUSOF');
    });

    test('rejects a token expired beyond clockSkewTolerance', () {
      final now = DateTime.now();
      final token = _jwt(
        _baseClaims(
          iat: now.subtract(const Duration(hours: 2)),
          exp: now.subtract(const Duration(hours: 1)),
        ),
      );

      expect(
        () => _service().validateClaims(token),
        throwsA(
          isA<HuwiyaClaimsException>().having((e) => e.claim, 'claim', 'exp'),
        ),
      );
    });
  });
}
