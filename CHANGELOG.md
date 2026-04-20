## 0.1.0

* Initial release.
* OAuth 2.0 + PKCE authorization code flow via `flutter_web_auth_2`.
* JWT claims validation (id, name, locale, zoneinfo, theme, scopes, iss, aud, exp, iat).
* Proactive token refresh with in-flight deduplication.
* Session restore on initialization from `flutter_secure_storage`.
* Reactive auth state via Riverpod (`authStateProvider`, `currentUserProvider`, `isAuthenticatedProvider`).
* Full typed exception hierarchy (`HuwiyaConfigException`, `HuwiyaAuthException`, `HuwiyaTokenException`, `HuwiyaClaimsException`, `HuwiyaStorageException`).
* Dio HTTP client with structured request/response/timing logger.
