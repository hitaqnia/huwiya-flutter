import 'package:flutter_test/flutter_test.dart';
import 'package:huwiya_sdk/src/models/auth_token.dart';

void main() {
  group('AuthToken.fromJson', () {
    test('parses a full token response with a refresh token', () {
      final token = AuthToken.fromJson(const {
        'token_type': 'Bearer',
        'expires_in': 1800,
        'access_token': 'access-abc',
        'refresh_token': 'refresh-xyz',
      });

      expect(token.accessToken, 'access-abc');
      expect(token.refreshToken, 'refresh-xyz');
      expect(token.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    test('tolerates a response without a refresh token', () {
      // Servers commonly omit refresh_token on repeat logins. This must not
      // throw a TypeError during sign-in.
      late final AuthToken token;
      expect(
        () => token = AuthToken.fromJson(const {
          'token_type': 'Bearer',
          'expires_in': 1800,
          'access_token': 'access-only',
        }),
        returnsNormally,
      );
      expect(token.accessToken, 'access-only');
      expect(token.refreshToken, isNull);
    });

    test('toJson omits a null refresh token', () {
      final token = AuthToken(
        accessToken: 'access-only',
        expiresAt: DateTime.now(),
      );
      expect(token.toJson().containsKey('refresh_token'), isFalse);
    });
  });
}
