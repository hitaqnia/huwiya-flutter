/// Base type for all errors thrown by the Huwiya SDK. Catch this to handle
/// any SDK error generically, or catch one of the specific subtypes.
abstract class HuwiyaException implements Exception {
  final String message;
  final Object? cause;

  const HuwiyaException(this.message, {this.cause});

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Thrown when `HuwiyaConfig` is missing or malformed at initialization.
class HuwiyaConfigException extends HuwiyaException {
  const HuwiyaConfigException(super.message, {super.cause});
}

/// Base type for sign-in / authorization failures.
class HuwiyaAuthException extends HuwiyaException {
  const HuwiyaAuthException(super.message, {super.cause});
}

/// Thrown when the user closes the browser before completing sign-in.
class UserCancelledException extends HuwiyaAuthException {
  const UserCancelledException([
    super.message = 'User cancelled the authentication flow',
  ]);
}

/// Thrown when Huwiya ID returns an `error` parameter on the redirect.
class ProviderException extends HuwiyaAuthException {
  final String error;
  final String? errorDescription;

  ProviderException(this.error, this.errorDescription)
    : super(
        'Provider error: $error${errorDescription != null ? ' — $errorDescription' : ''}',
      );
}

/// Thrown when the CSRF `state` parameter on the redirect does not match the
/// state generated for this sign-in attempt.
class StateMismatchException extends HuwiyaAuthException {
  const StateMismatchException()
    : super(
        'CSRF state mismatch — redirect state does not match generated state',
      );
}

/// Thrown when the redirect is missing a required parameter (`code` / `state`).
class MissingParametersException extends HuwiyaAuthException {
  const MissingParametersException(String missing)
    : super('Redirect is missing required parameter(s): $missing');
}

/// Thrown for transport / network failures during token exchange or refresh.
class HuwiyaTokenException extends HuwiyaException {
  const HuwiyaTokenException(super.message, {super.cause});
}

/// Thrown when the token endpoint returns a 4xx error body with an
/// OAuth-style `error` field.
class TokenErrorResponseException extends HuwiyaTokenException {
  final String error;
  final String? errorDescription;

  TokenErrorResponseException(this.error, this.errorDescription)
    : super(
        'Token error: $error${errorDescription != null ? ' — $errorDescription' : ''}',
      );
}

/// Thrown when JWT claims validation fails. [claim] names the failing claim
/// and [reason] explains why.
class HuwiyaClaimsException extends HuwiyaException {
  final String claim;
  final String reason;

  HuwiyaClaimsException({required this.claim, required this.reason})
    : super('JWT claims validation failed for "$claim": $reason');
}

/// Thrown for read/write/delete failures against secure storage.
class HuwiyaStorageException extends HuwiyaException {
  const HuwiyaStorageException(super.message, {super.cause});
}
