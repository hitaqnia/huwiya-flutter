import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/authorize_service.dart';
import '../auth/refresh_service.dart';
import '../auth/token_service.dart';
import '../exceptions/huwiya_exceptions.dart';
import '../providers/sdk_providers.dart';
import '../storage/secure_storage_service.dart';
import 'huwiya_config.dart';

class HuwiyaSDK {
  static HuwiyaSDK? _instance;

  final HuwiyaConfig _config;
  final ProviderContainer _container;
  final AuthorizeService _authorizeService;
  final TokenService _tokenService;
  final SecureStorageService _storage;
  final RefreshService _refreshService;
  final AuthStateNotifier _notifier;

  HuwiyaSDK._({
    required HuwiyaConfig config,
    required ProviderContainer container,
    required AuthorizeService authorizeService,
    required TokenService tokenService,
    required SecureStorageService storage,
    required RefreshService refreshService,
    required AuthStateNotifier notifier,
  }) : _config = config,
       _container = container,
       _authorizeService = authorizeService,
       _tokenService = tokenService,
       _storage = storage,
       _refreshService = refreshService,
       _notifier = notifier;

  static Future<HuwiyaSDK> initialize(HuwiyaConfig config) async {
    config.validate();

    final container = ProviderContainer(
      overrides: [huwiyaConfigProvider.overrideWithValue(config)],
    );

    final storage = container.read(secureStorageServiceProvider);
    final notifier = container.read(authStateProvider.notifier);
    final refreshService = container.read(refreshServiceProvider);
    final authorizeService = container.read(authorizeServiceProvider);
    final tokenService = container.read(tokenServiceProvider);

    refreshService.installAuthInterceptor();

    final sdk = HuwiyaSDK._(
      config: config,
      container: container,
      authorizeService: authorizeService,
      tokenService: tokenService,
      storage: storage,
      refreshService: refreshService,
      notifier: notifier,
    );

    await refreshService.restoreSession();

    _instance = sdk;
    return sdk;
  }

  static HuwiyaSDK get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'HuwiyaSDK has not been initialized. Call HuwiyaSDK.initialize() first.',
      );
    }
    return inst;
  }

  Future<void> signIn() async {
    _notifier.setAuthenticating();
    try {
      final (:code, :codeVerifier) = await _authorizeService.authorize();
      final (:token, :user) = await _tokenService.exchange(
        code: code,
        codeVerifier: codeVerifier,
      );
      await _storage.saveTokens(token);
      _notifier.setAuthenticated(user, accessToken: token.accessToken);
    } on HuwiyaException catch (e) {
      _notifier.setError(e);
      rethrow;
    } catch (e) {
      final wrapped = HuwiyaAuthException(
        'Unexpected error during sign-in',
        cause: e,
      );
      _notifier.setError(wrapped);
      throw wrapped;
    }
  }

  Future<void> signOut() async {
    await _refreshService.signOut();
  }

  Future<String> getAccessToken() => _refreshService.getAccessToken();

  AuthStateNotifier get authNotifier => _notifier;

  ProviderContainer get providerContainer => _container;

  HuwiyaConfig get config => _config;
}
