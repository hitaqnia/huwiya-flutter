import '../exceptions/huwiya_exceptions.dart';

/// Configuration for [HuwiyaSDK].
///
/// All fields are required except [scopes]. Validation runs eagerly during
/// `HuwiyaSDK.initialize` and throws [HuwiyaConfigException] on bad input.
class HuwiyaConfig {
  /// Base URL of the Huwiya ID server (must be HTTPS).
  final String baseUrl;

  /// Project (tenant) identifier — used to validate the `aud` JWT claim.
  final String projectId;

  /// OAuth 2.0 client identifier registered with Huwiya ID.
  final String clientId;

  /// Redirect URI registered with Huwiya ID. Must use a custom scheme that
  /// matches the platform setup in your `AndroidManifest.xml` / `Info.plist`
  /// (e.g. `com.example.app://auth/callback`).
  final String redirectUri;

  /// OAuth scopes to request. Defaults to an empty list (server-default scopes).
  final List<String> scopes;

  const HuwiyaConfig({
    required this.baseUrl,
    required this.projectId,
    required this.clientId,
    required this.redirectUri,
    this.scopes = const [],
  });

  /// Validates the config. Throws [HuwiyaConfigException] if any field is
  /// missing or malformed. Called automatically by `HuwiyaSDK.initialize`.
  void validate() {
    if (baseUrl.isEmpty) {
      throw const HuwiyaConfigException('baseUrl must not be empty');
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || baseUri.scheme != 'https') {
      throw HuwiyaConfigException(
        'baseUrl must be a valid HTTPS URI, got: "$baseUrl"',
      );
    }

    if (projectId.isEmpty) {
      throw const HuwiyaConfigException('projectId must not be empty');
    }

    if (clientId.isEmpty) {
      throw const HuwiyaConfigException('clientId must not be empty');
    }

    if (redirectUri.isEmpty) {
      throw const HuwiyaConfigException('redirectUri must not be empty');
    }

    final redirectUriParsed = Uri.tryParse(redirectUri);
    if (redirectUriParsed == null) {
      throw HuwiyaConfigException(
        'redirectUri must be a valid URI, got: "$redirectUri"',
      );
    }

    for (final scope in scopes) {
      if (scope.isEmpty) {
        throw const HuwiyaConfigException(
          'Each scope must be a non-empty string',
        );
      }
    }
  }

  @override
  String toString() =>
      'HuwiyaConfig(baseUrl: $baseUrl, projectId: $projectId, clientId: $clientId, '
      'redirectUri: $redirectUri, scopes: $scopes)';
}
