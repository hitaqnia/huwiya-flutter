import '../exceptions/huwiya_exceptions.dart';
import '../models/huwiya_user.dart';

/// Reactive authentication state emitted by `HuwiyaSDK.authStateStream`.
///
/// Sealed; pattern-match on the variants in a `switch` expression.
sealed class AuthState {
  const AuthState();
}

/// No active session.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// A sign-in flow is in progress (browser open, awaiting redirect).
class Authenticating extends AuthState {
  const Authenticating();
}

/// Authenticated with a valid session. Carries the signed-in [user].
class Authenticated extends AuthState {
  final HuwiyaUser user;
  const Authenticated(this.user);
}

/// A token refresh is in progress; the previous session is still valid until
/// the refresh completes or fails.
class Refreshing extends AuthState {
  final HuwiyaUser user;
  const Refreshing(this.user);
}

/// A typed [HuwiyaException] occurred during sign-in or refresh.
class AuthError extends AuthState {
  final HuwiyaException error;
  const AuthError(this.error);
}
