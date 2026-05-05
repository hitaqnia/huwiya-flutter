import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../core/huwiya_config.dart';
import '../exceptions/huwiya_exceptions.dart';
import 'pkce_service.dart';

class AuthorizeService {
  final HuwiyaConfig _config;
  final PkceService _pkceService;

  AuthorizeService({required HuwiyaConfig config, PkceService? pkceService})
    : _config = config,
      _pkceService = pkceService ?? PkceService();

  Future<({String code, String codeVerifier})> authorize() async {
    final pkce = _pkceService.generate();

    final authorizeUrl = _buildAuthorizeUrl(pkce);
    final callbackScheme = _schemeFrom(_config.redirectUri);

    final String resultUrl;
    try {
      resultUrl = await FlutterWebAuth2.authenticate(
        url: authorizeUrl.toString(),
        callbackUrlScheme: callbackScheme,
      );
    } on Exception catch (e) {
      final message = e.toString();
      if (message.contains('CANCELED') ||
          message.contains('USER_CANCELLED') ||
          message.contains('user_cancelled') ||
          message.contains('canceled')) {
        throw const UserCancelledException();
      }
      throw HuwiyaAuthException('Browser authentication failed', cause: e);
    }

    final code = _parseRedirect(resultUrl, expectedState: pkce.state);
    return (code: code, codeVerifier: pkce.codeVerifier);
  }

  Uri _buildAuthorizeUrl(PkceValues pkce) {
    final base = Uri.parse(_config.baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '${base.path}/oauth/authorize',
      queryParameters: {
        'response_type': 'code',
        'client_id': _config.clientId,
        'redirect_uri': _config.redirectUri,
        if (_config.scopes.isNotEmpty) 'scope': _config.scopes.join(' '),
        'state': pkce.state,
        'code_challenge': pkce.codeChallenge,
        'code_challenge_method': 'S256',
      },
    );
  }

  String _parseRedirect(String redirectUrl, {required String expectedState}) {
    final uri = Uri.parse(redirectUrl);

    final error = uri.queryParameters['error'];
    if (error != null) {
      throw ProviderException(error, uri.queryParameters['error_description']);
    }

    final returnedState = uri.queryParameters['state'];
    if (returnedState == null || returnedState != expectedState) {
      throw const StateMismatchException();
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw const MissingParametersException('code');
    }

    return code;
  }

  String _schemeFrom(String redirectUri) {
    final uri = Uri.parse(redirectUri);
    return uri.scheme;
  }
}
