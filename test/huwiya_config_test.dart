import 'package:flutter_test/flutter_test.dart';
import 'package:huwiya_sdk/huwiya_sdk.dart';

void main() {
  group('HuwiyaConfig.validate', () {
    HuwiyaConfig validConfig({
      String baseUrl = 'https://id.example.com',
      String projectId = 'proj_123',
      String clientId = 'client_abc',
      String redirectUri = 'com.example.app://auth/callback',
      List<String> scopes = const ['openid', 'profile'],
    }) => HuwiyaConfig(
      baseUrl: baseUrl,
      projectId: projectId,
      clientId: clientId,
      redirectUri: redirectUri,
      scopes: scopes,
    );

    test('accepts a well-formed config', () {
      expect(() => validConfig().validate(), returnsNormally);
    });

    test('accepts an empty scopes list', () {
      expect(
        () => validConfig(scopes: const []).validate(),
        returnsNormally,
      );
    });

    test('rejects empty baseUrl', () {
      expect(
        () => validConfig(baseUrl: '').validate(),
        throwsA(isA<HuwiyaConfigException>()),
      );
    });

    test('rejects non-HTTPS baseUrl', () {
      expect(
        () => validConfig(baseUrl: 'http://id.example.com').validate(),
        throwsA(isA<HuwiyaConfigException>()),
      );
    });

    test('rejects empty projectId', () {
      expect(
        () => validConfig(projectId: '').validate(),
        throwsA(isA<HuwiyaConfigException>()),
      );
    });

    test('rejects empty clientId', () {
      expect(
        () => validConfig(clientId: '').validate(),
        throwsA(isA<HuwiyaConfigException>()),
      );
    });

    test('rejects empty redirectUri', () {
      expect(
        () => validConfig(redirectUri: '').validate(),
        throwsA(isA<HuwiyaConfigException>()),
      );
    });

    test('rejects an empty scope entry', () {
      expect(
        () => validConfig(scopes: const ['openid', '']).validate(),
        throwsA(isA<HuwiyaConfigException>()),
      );
    });

    test('defaults clockSkewTolerance to 5 minutes and validateIssuedAt to false', () {
      const config = HuwiyaConfig(
        baseUrl: 'https://id.example.com',
        projectId: 'proj_123',
        clientId: 'client_abc',
        redirectUri: 'com.example.app://auth/callback',
      );
      expect(config.clockSkewTolerance, const Duration(minutes: 5));
      expect(config.validateIssuedAt, isFalse);
    });

    test('accepts a zero clockSkewTolerance', () {
      const config = HuwiyaConfig(
        baseUrl: 'https://id.example.com',
        projectId: 'proj_123',
        clientId: 'client_abc',
        redirectUri: 'com.example.app://auth/callback',
        clockSkewTolerance: Duration.zero,
      );
      expect(config.validate, returnsNormally);
    });

    test('rejects a negative clockSkewTolerance', () {
      const config = HuwiyaConfig(
        baseUrl: 'https://id.example.com',
        projectId: 'proj_123',
        clientId: 'client_abc',
        redirectUri: 'com.example.app://auth/callback',
        clockSkewTolerance: Duration(seconds: -1),
      );
      expect(config.validate, throwsA(isA<HuwiyaConfigException>()));
    });
  });
}
