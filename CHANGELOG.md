## 0.2.1

* **Tolerate a missing `refresh_token`.** OAuth servers often return a
  `refresh_token` only on the first authorization and omit it on subsequent
  logins. Sign-in previously crashed with `Unexpected error during sign-in`
  (a `TypeError` from a non-null cast) in that case. `AuthToken.refreshToken`
  is now nullable and the storage/refresh paths handle its absence: the session
  is restored from the access token, and refresh is skipped (the access token is
  used until it expires) when no refresh token is available.
* Include the underlying cause in the `Unexpected error during sign-in` message
  for easier diagnosis.

## 0.2.0

* **Clock-skew tolerance for JWT validation.** Added `HuwiyaConfig.clockSkewTolerance`
  (default 5 minutes) that drives the grace window for the `exp` (and optional `iat`)
  claim checks, replacing the previous hard-coded 60-second window.
* **Issued-at validation is now opt-in.** Added `HuwiyaConfig.validateIssuedAt`
  (default `false`). An `iat` in the future is almost always a wrong *device* clock
  rather than a security problem, so it no longer blocks sign-in by default. Set
  `validateIssuedAt: true` to restore strict issued-at checking.

  This fixes sign-in failing with `HuwiyaClaimsException(claim: iat)` on devices/
  emulators whose clock lags behind the Huwiya ID server.

## 0.1.0

* Initial release.
* OAuth 2.0 + PKCE authorization code flow via `flutter_web_auth_2`.
* JWT claims validation (id, name, locale, zoneinfo, theme, scopes, iss, aud, exp, iat).
* Proactive token refresh with in-flight deduplication.
* Session restore on initialization from `flutter_secure_storage`.
* Reactive auth state via Riverpod (`authStateProvider`, `currentUserProvider`, `isAuthenticatedProvider`).
* Full typed exception hierarchy (`HuwiyaConfigException`, `HuwiyaAuthException`, `HuwiyaTokenException`, `HuwiyaClaimsException`, `HuwiyaStorageException`).
* Dio HTTP client with structured request/response/timing logger.
