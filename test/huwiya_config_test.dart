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
  });
}
