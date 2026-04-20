import '../exceptions/huwiya_exceptions.dart';
import '../models/huwiya_user.dart';

sealed class AuthState {
  const AuthState();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class Authenticating extends AuthState {
  const Authenticating();
}

class Authenticated extends AuthState {
  final HuwiyaUser user;
  const Authenticated(this.user);
}

class Refreshing extends AuthState {
  final HuwiyaUser user;
  const Refreshing(this.user);
}

class AuthError extends AuthState {
  final HuwiyaException error;
  const AuthError(this.error);
}
