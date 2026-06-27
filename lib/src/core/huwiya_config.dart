import '../exceptions/huwiya_exceptions.dart';

/// Configuration for [HuwiyaSDK].
///
/// All fields are required except [scopes], [clockSkewTolerance], and
/// [validateIssuedAt]. Validation runs eagerly during `HuwiyaSDK.initialize`
/// and throws [HuwiyaConfigException] on bad input.
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

  /// Maximum allowed clock difference between this device and the Huwiya ID
  /// server when validating time-based JWT claims.
  ///
  /// Applied to the `exp` (expiry) check, and to the `iat` (issued-at) check
  /// when [validateIssuedAt] is enabled. Defaults to 5 minutes — the
  /// conventional OIDC clock-skew allowance. Must not be negative.
  final Duration clockSkewTolerance;

  /// Whether to reject access tokens whose `iat` (issued-at) claim is in the
  /// future beyond [clockSkewTolerance].
  ///
  /// Defaults to `false`. An `iat` in the future almost always indicates a
  /// wrong *device* clock rather than a security problem (the security-relevant
  /// claim is `exp`), so by default it does not block sign-in. Set to `true`
  /// to opt into strict issued-at validation.
  final bool validateIssuedAt;

  const HuwiyaConfig({
    required this.baseUrl,
    required this.projectId,
    required this.clientId,
    required this.redirectUri,
    this.scopes = const [],
    this.clockSkewTolerance = const Duration(minutes: 5),
    this.validateIssuedAt = false,
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

    if (clockSkewTolerance.isNegative) {
      throw const HuwiyaConfigException(
        'clockSkewTolerance must not be negative',
      );
    }
  }

  @override
  String toString() =>
      'HuwiyaConfig(baseUrl: $baseUrl, projectId: $projectId, clientId: $clientId, '
      'redirectUri: $redirectUri, scopes: $scopes, '
      'clockSkewTolerance: $clockSkewTolerance, validateIssuedAt: $validateIssuedAt)';
}
