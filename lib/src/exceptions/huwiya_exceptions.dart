abstract class HuwiyaException implements Exception {
  final String message;
  final Object? cause;

  const HuwiyaException(this.message, {this.cause});

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

class HuwiyaConfigException extends HuwiyaException {
  const HuwiyaConfigException(super.message, {super.cause});
}

class HuwiyaAuthException extends HuwiyaException {
  const HuwiyaAuthException(super.message, {super.cause});
}

class UserCancelledException extends HuwiyaAuthException {
  const UserCancelledException([
    super.message = 'User cancelled the authentication flow',
  ]);
}

class ProviderException extends HuwiyaAuthException {
  final String error;
  final String? errorDescription;

  ProviderException(this.error, this.errorDescription)
    : super(
        'Provider error: $error${errorDescription != null ? ' — $errorDescription' : ''}',
      );
}

class StateMismatchException extends HuwiyaAuthException {
  const StateMismatchException()
    : super(
        'CSRF state mismatch — redirect state does not match generated state',
      );
}

class MissingParametersException extends HuwiyaAuthException {
  const MissingParametersException(String missing)
    : super('Redirect is missing required parameter(s): $missing');
}

class HuwiyaTokenException extends HuwiyaException {
  const HuwiyaTokenException(super.message, {super.cause});
}

class TokenErrorResponseException extends HuwiyaTokenException {
  final String error;
  final String? errorDescription;

  TokenErrorResponseException(this.error, this.errorDescription)
    : super(
        'Token error: $error${errorDescription != null ? ' — $errorDescription' : ''}',
      );
}

class HuwiyaClaimsException extends HuwiyaException {
  final String claim;
  final String reason;

  HuwiyaClaimsException({required this.claim, required this.reason})
    : super('JWT claims validation failed for "$claim": $reason');
}

class HuwiyaStorageException extends HuwiyaException {
  const HuwiyaStorageException(super.message, {super.cause});
}
