import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_notifier.dart';
import '../auth/auth_state.dart';
import '../auth/authorize_service.dart';
import '../auth/refresh_service.dart';
import '../auth/token_service.dart';
import '../core/huwiya_config.dart';
import '../models/huwiya_user.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage_service.dart';

final huwiyaConfigProvider = Provider<HuwiyaConfig>(
  (ref) =>
      throw UnimplementedError('HuwiyaSDK.initialize() must be called first'),
);

final secureStorageServiceProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

final dioClientProvider = Provider<Dio>((ref) {
  final config = ref.watch(huwiyaConfigProvider);
  return DioClient(config).instance;
});

final tokenServiceProvider = Provider<TokenService>((ref) {
  final dio = ref.watch(dioClientProvider);
  final config = ref.watch(huwiyaConfigProvider);
  return TokenService(dio: dio, config: config);
});

final authorizeServiceProvider = Provider<AuthorizeService>((ref) {
  final config = ref.watch(huwiyaConfigProvider);
  return AuthorizeService(config: config);
});

final refreshServiceProvider = Provider<RefreshService>((ref) {
  final dio = ref.watch(dioClientProvider);
  final config = ref.watch(huwiyaConfigProvider);
  final storage = ref.watch(secureStorageServiceProvider);
  final notifier = ref.watch(authStateProvider.notifier);
  return RefreshService(
    dio: dio,
    config: config,
    storage: storage,
    notifier: notifier,
  );
});

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(),
);

final currentUserProvider = Provider<HuwiyaUser?>((ref) {
  final state = ref.watch(authStateProvider);
  return state is Authenticated ? state.user : null;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider) is Authenticated;
});
