import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../exceptions/huwiya_exceptions.dart';
import '../models/huwiya_user.dart';
import 'auth_state.dart';

class AuthStateNotifier extends StateNotifier<AuthState> {
  String? _currentAccessToken;

  AuthStateNotifier() : super(const Unauthenticated());

  void setAuthenticating() => state = const Authenticating();

  void setAuthenticated(HuwiyaUser user, {String? accessToken}) {
    if (accessToken != null) _currentAccessToken = accessToken;
    state = Authenticated(user);
  }

  void setRefreshing() {
    final currentUser = this.currentUser;
    if (currentUser != null) {
      state = Refreshing(currentUser);
    }
  }

  void setUnauthenticated() {
    _currentAccessToken = null;
    state = const Unauthenticated();
  }

  void setError(HuwiyaException error) => state = AuthError(error);

  void updateAccessToken(String accessToken) {
    _currentAccessToken = accessToken;
  }

  HuwiyaUser? get currentUser {
    final s = state;
    return switch (s) {
      Authenticated(:final user) => user,
      Refreshing(:final user) => user,
      _ => null,
    };
  }

  String? get currentAccessToken => _currentAccessToken;
}
