import '../exceptions/huwiya_exceptions.dart';

class HuwiyaConfig {
  final String baseUrl;

  final String projectId;

  final String clientId;

  final String redirectUri;

  final List<String> scopes;

  const HuwiyaConfig({
    required this.baseUrl,
    required this.projectId,
    required this.clientId,
    required this.redirectUri,
    this.scopes = const [],
  });

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
