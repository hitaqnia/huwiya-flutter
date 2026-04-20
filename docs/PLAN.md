# Huwiya Flutter SDK — Implementation Plan

**Package name:** `huwiya_sdk`
**Pub.dev publisher:** `huwiya-flutter`
**SDK name (display):** Huwiya Flutter SDK

---

## Agent Context Optimization

Before any implementation phase begins, disable all non-essential agent capabilities
(web search, browser access, image analysis, etc.) to keep context usage lean and
focused purely on code generation. Only code-reading, file-writing, and terminal
tools are needed throughout this plan.

---

## Technology Stack (locked)

| Concern | Choice |
|---|---|
| HTTP client | `dio` with a custom `LoggingInterceptor` |
| Secure storage | `flutter_secure_storage` |
| Browser / redirect capture | `flutter_web_auth_2` |
| Internal DI / service wiring | `flutter_riverpod` — plain providers + `StateNotifier` (no code-gen, never exported) |
| Public reactive surface | `dart:async` `Stream<AuthState>` — zero framework coupling |
| JWT parsing | manual base64url-decode + `dart:convert` JSON |
| PKCE crypto | `dart:math` `Random.secure()` + `crypto` (sha256) |
| Models | hand-written Dart classes, `fromJson` / `toJson` only (no build_runner) |

> **State management independence:** Riverpod is used **only** as an internal
> dependency-injection mechanism to wire the SDK's services together. It is never
> part of the public API and is never exported from the barrel. The public reactive
> surface is a plain `Stream<AuthState>` from `dart:async`, which any state
> management solution (Riverpod, Bloc, GetX, Provider, MobX, plain setState) can
> consume without knowing anything about the SDK's internals.

---

## Phase 1 — Package Foundation & Public API Surface

**Goal:** Clean package skeleton, locked dependency set, public API contracts (classes,
models, exceptions), and a validated `HuwiyaSDK.initialize()` entry point.
No network, browser, or storage logic in this phase.

### 1.1 Update `pubspec.yaml`

```yaml
name: huwiya_sdk
description: "Huwiya Flutter SDK — OAuth 2.0 + PKCE authentication for Flutter apps."
version: 0.1.0
homepage: https://pub.dev/packages/huwiya_sdk
repository: https://github.com/huwiya-flutter/huwiya_sdk

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  dio: ^5.7.0
  flutter_riverpod: ^2.6.1        # internal DI only — never exported
  flutter_secure_storage: ^9.2.2
  flutter_web_auth_2: ^4.0.0
  crypto: ^3.0.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

### 1.2 Package Directory Layout

```
lib/
  huwiya_sdk.dart                  ← single public barrel (Riverpod never appears here)
  src/
    core/
      huwiya_sdk_core.dart         ← HuwiyaSDK class: initialize, signIn, signOut, getAccessToken
      huwiya_config.dart           ← HuwiyaConfig + validation
    models/
      huwiya_user.dart             ← HuwiyaUser
      auth_token.dart              ← AuthToken (accessToken, refreshToken, expiresAt)
    auth/
      auth_state.dart              ← sealed AuthState variants (plain Dart, no framework dep)
      auth_notifier.dart           ← AuthStateNotifier extends StateNotifier<AuthState> (internal)
      pkce_service.dart            ← PKCE values generation (internal)
      authorize_service.dart       ← authorize URL + browser + redirect parsing (internal)
      token_service.dart           ← token exchange + JWT validation (internal)
      refresh_service.dart         ← proactive refresh + deduplication (internal)
    storage/
      secure_storage_service.dart  ← read/write/clear tokens (internal)
    network/
      dio_client.dart              ← Dio singleton (internal)
      logging_interceptor.dart     ← full request/response/timing logger (internal)
    exceptions/
      huwiya_exceptions.dart       ← all typed exceptions (exported)
    providers/
      sdk_providers.dart           ← Riverpod providers for internal wiring (NEVER exported)
```

### 1.3 `HuwiyaConfig` Model

Fields — all required, all validated at init:

| Field | Type | Validation |
|---|---|---|
| `baseUrl` | `String` | non-empty, must parse as HTTPS URI |
| `projectId` | `String` | non-empty |
| `clientId` | `String` | non-empty |
| `redirectUri` | `String` | non-empty, must parse as URI |
| `scopes` | `List<String>` | non-empty list, each scope non-empty |

Expose a `validate()` method that throws `HuwiyaConfigException` on any failure.
`HuwiyaConfig` is immutable — `final` fields, constructor-only assignment.

### 1.4 Typed Exception Hierarchy

All exceptions extend the common base `HuwiyaException` (implements `Exception`).

```
HuwiyaException (base)
  ├── HuwiyaConfigException           — bad/missing config at init
  ├── HuwiyaAuthException             — generic auth failure
  │     ├── UserCancelledException         — user closed the browser
  │     ├── ProviderException              — error/error_description from Huwiya ID redirect
  │     ├── StateMismatchException         — CSRF state mismatch on redirect
  │     └── MissingParametersException     — redirect missing code or state
  ├── HuwiyaTokenException            — token exchange or refresh HTTP failure
  │     └── TokenErrorResponseException   — 4xx with error body from /oauth/token
  ├── HuwiyaClaimsException           — JWT claims validation failure (which claim + why)
  └── HuwiyaStorageException          — secure storage read/write failure
```

Each exception carries a human-readable `message` and an optional `cause` (`Object?`)
for wrapping lower-level errors.

### 1.5 `HuwiyaUser` Model

```dart
class HuwiyaUser {
  final String id;           // ULID — primary user identifier (no sub claim)
  final String name;
  final String locale;
  final String zoneinfo;
  final String theme;
  final List<String> scopes;
  // Standard JWT claims — nullable, present when validated
  final String?   iss;
  final String?   aud;
  final DateTime? iat;
  final DateTime? exp;
}
```

Hand-written `fromJson` factory — no code generation.

### 1.6 `HuwiyaSDK` Entry Point & Public API

```dart
class HuwiyaSDK {
  // Lifecycle
  static Future<HuwiyaSDK> initialize(HuwiyaConfig config);
  static HuwiyaSDK get instance; // throws StateError if not initialized

  // Auth actions
  Future<void>   signIn();
  Future<void>   signOut();
  Future<String> getAccessToken();

  // Framework-agnostic reactive surface
  Stream<AuthState> get authStateStream; // broadcast stream — subscribe from any framework
  HuwiyaUser?       get currentUser;     // synchronous snapshot of current user
}
```

`initialize()` must:
1. Call `config.validate()` — throws `HuwiyaConfigException` immediately on bad config.
2. Wire up all internal services via the internal Riverpod `ProviderContainer`.
3. Attempt session restoration from secure storage.
4. Store the instance and return it.

The internal `ProviderContainer` is never exposed. The `authStateStream` is backed by
a `StreamController<AuthState>.broadcast()` that the internal `AuthStateNotifier`
pushes into on every state transition.

---

## Phase 2 — PKCE Authorization Flow

**Goal:** Generate PKCE values, build the authorize URL, open the secure browser,
capture the redirect, validate state, and return a verified authorization code.

### 2.1 PKCE Value Generation (`PkceService` — internal)

```dart
class PkceValues {
  final String codeVerifier;
  final String codeChallenge;
  final String state;
}
```

Generation (all in one call — atomic, never reused across requests):

- **`codeVerifier`** — 32 bytes from `Random.secure()`, base64url-encoded without
  padding → 43 characters, spec-compliant per RFC 7636.
- **`codeChallenge`** — `sha256.convert(utf8.encode(codeVerifier))` bytes, then
  `base64UrlEncode` trimmed of trailing `=`.
- **`state`** — 16+ bytes from `Random.secure()`, base64url-encoded without padding.

Values are held in memory only during the sign-in flow. `codeVerifier` is passed
forward to Phase 3. All three are discarded after token exchange completes.

### 2.2 Authorize URL Builder

Build a `Uri` from `config.baseUrl + /oauth/authorize` with query params:

| Param | Value |
|---|---|
| `response_type` | `code` |
| `client_id` | `config.clientId` |
| `redirect_uri` | `config.redirectUri` |
| `scope` | `config.scopes.join(' ')` |
| `state` | generated `state` |
| `code_challenge` | generated `code_challenge` |
| `code_challenge_method` | `S256` |

### 2.3 Browser Launch & Redirect Capture (`AuthorizeService` — internal)

Use `flutter_web_auth_2`:

```dart
final result = await WebAuth2.authenticate(
  url: authorizeUrl.toString(),
  callbackUrlScheme: _schemeFrom(config.redirectUri),
);
```

Extract the scheme portion from `config.redirectUri` for `callbackUrlScheme`
(e.g. `"com.example.app://callback"` → `"com.example.app"`).

`PlatformException` mapping:
- User-cancelled code → `UserCancelledException`
- Any other platform failure → `HuwiyaAuthException` wrapping the cause

### 2.4 Redirect Validation

Parse the returned URL into a `Uri`, then in order:

1. `error` param present → throw `ProviderException(error, errorDescription)`.
2. `state` absent or mismatched → throw `StateMismatchException`.
3. `code` absent or empty → throw `MissingParametersException`.
4. Return `code` string to the caller.

**Output of Phase 2:** `String authorizationCode` + in-memory `codeVerifier`.

---

## Phase 3 — Token Exchange, JWT Validation & Secure Storage

**Goal:** Exchange the authorization code for tokens, validate JWT claims, persist to
secure storage on success, and surface a typed `HuwiyaUser`.

### 3.1 Dio Client & Logging Interceptor (internal)

Singleton `Dio` instance configured with:
- `baseUrl` from config, `connectTimeout` / `receiveTimeout` 30s.
- `contentType: 'application/x-www-form-urlencoded'` as default.

`LoggingInterceptor` (custom — no third-party logger dependency):

- **Request:** method, full URL, headers, body, timestamp.
- **Response:** status code, headers, body, **elapsed time** (via `Stopwatch` started
  at request, stopped at response).
- **Error:** status code, error type, message, response body if available.
- Output via `debugPrint` with clear separator blocks for readability in console.

An `AuthInterceptor` is added in Phase 5 to attach `Bearer` tokens automatically.

### 3.2 Token Exchange (`TokenService.exchange` — internal)

POST `{baseUrl}/oauth/token`, body:

```
grant_type=authorization_code
client_id={clientId}
redirect_uri={redirectUri}
code={authorizationCode}
code_verifier={codeVerifier}
```

Note: this is a public client — no `client_secret` in any request.

On HTTP 200 → parse JSON into `AuthToken`:
```dart
class AuthToken {
  final String   accessToken;
  final String   refreshToken;
  final DateTime expiresAt; // DateTime.now().add(Duration(seconds: expiresIn))
}
```

On 4xx → parse `error` + `error_description` → throw `TokenErrorResponseException`.
On `DioException` (network/timeout) → throw `HuwiyaTokenException` wrapping cause.

**Tokens are NOT stored yet** — claims validation runs first. If validation fails,
tokens are discarded and never written to storage.

### 3.3 JWT Claims Validation (`TokenService._validateClaims` — internal)

Manual decode — no signature verification (handled server-side):

```dart
final parts   = accessToken.split('.');
final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
final claims  = jsonDecode(payload) as Map<String, dynamic>;
```

Validate in order — throw `HuwiyaClaimsException(claim: '...', reason: '...')` on
the first failure:

1. `id` — present, non-empty string, exactly 26 characters (ULID length).
2. `name` — present, non-empty string.
3. `locale` — present, non-empty string.
4. `zoneinfo` — present, non-empty string.
5. `theme` — present, non-empty string.
6. `scopes` — present, `List` type, non-empty, all elements are strings.
7. `iss` (if present) — must equal `config.baseUrl`.
8. `aud` (if present) — must equal `config.projectId`.
9. `exp` (if present) — must be after `DateTime.now().subtract(Duration(seconds: 60))`.
10. `iat` (if present) — must not be more than 60s in the future.

On success → build and return `HuwiyaUser` from the claims map.

### 3.4 Secure Storage Service (`SecureStorageService` — internal)

Thin wrapper over `flutter_secure_storage`. Three keys:

```dart
static const _keyAccessToken  = 'huwiya_access_token';
static const _keyRefreshToken = 'huwiya_refresh_token';
static const _keyExpiresAt    = 'huwiya_expires_at';  // stored as ISO-8601 string
```

Methods:
- `Future<void> saveTokens(AuthToken token)`
- `Future<AuthToken?> readTokens()`
- `Future<void> clearTokens()`

All wrapped in try/catch → `HuwiyaStorageException` on failure.

Platform options:
- Android: `AndroidOptions(encryptedSharedPreferences: true)`
- iOS: `IOSOptions(accessibility: KeychainAccessibility.firstUnlock)`

### 3.5 Session Restoration at Init

Inside `HuwiyaSDK.initialize()`, after wiring services:
1. `SecureStorageService.readTokens()`.
2. Tokens present + `expiresAt > now + 60s` → validate access token claims → push
   `Authenticated(user)` onto the state stream.
3. Tokens present but expired → attempt silent refresh (Phase 5 logic, called inline).
4. No tokens → stream starts at `Unauthenticated()` (the default).

---

## Phase 4 — Reactive Auth State

**Goal:** Internal `AuthStateNotifier` drives a public `Stream<AuthState>` that any
host-app state management can consume without coupling to the SDK's internals.

### 4.1 `AuthState` Sealed Class (exported — plain Dart)

```dart
sealed class AuthState {
  const AuthState();
}

class Unauthenticated  extends AuthState { const Unauthenticated(); }
class Authenticating   extends AuthState { const Authenticating(); }
class Authenticated    extends AuthState {
  final HuwiyaUser user;
  const Authenticated(this.user);
}
class Refreshing       extends AuthState {
  final HuwiyaUser user; // session still valid during background refresh
  const Refreshing(this.user);
}
class AuthError        extends AuthState {
  final HuwiyaException error;
  const AuthError(this.error);
}
```

`AuthState` and its variants are exported from the public barrel. They have zero
dependency on Riverpod or any other framework.

### 4.2 `AuthStateNotifier` (internal — `StateNotifier<AuthState>`)

Internal to the SDK. Drives both the internal Riverpod state and the public stream.

```dart
class AuthStateNotifier extends StateNotifier<AuthState> {
  final StreamController<AuthState> _streamController;

  AuthStateNotifier(this._streamController) : super(const Unauthenticated());

  @override
  set state(AuthState value) {
    super.state = value;
    _streamController.add(value); // forward every transition to the public stream
  }

  void setAuthenticating() => state = const Authenticating();
  void setAuthenticated(HuwiyaUser user) => state = Authenticated(user);
  void setRefreshing(HuwiyaUser user) => state = Refreshing(user);
  void setUnauthenticated() => state = const Unauthenticated();
  void setError(HuwiyaException error) => state = AuthError(error);

  HuwiyaUser? get currentUser {
    final s = state;
    return (s is Authenticated) ? s.user : (s is Refreshing) ? s.user : null;
  }
}
```

### 4.3 Public Stream on `HuwiyaSDK`

Inside `HuwiyaSDK`, created once at `initialize()`:

```dart
final _stateController = StreamController<AuthState>.broadcast();
late final Stream<AuthState> authStateStream = _stateController.stream;
```

The `_stateController` is passed to `AuthStateNotifier`. Every internal state
transition pushes to the stream. The host app subscribes however it wants:

```dart
// Plain Flutter — no framework needed
StreamBuilder<AuthState>(
  stream: HuwiyaSDK.instance.authStateStream,
  builder: (context, snapshot) { ... },
)

// Riverpod host (SDK has no knowledge of this)
final authStateProvider = StreamProvider<AuthState>(
  (ref) => HuwiyaSDK.instance.authStateStream,
);

// Bloc host
sdk.authStateStream.listen((state) => add(AuthStateChanged(state)));

// GetX host
sdk.authStateStream.listen((state) => authState.value = state);
```

### 4.4 Internal Riverpod Providers (`sdk_providers.dart` — NEVER exported)

```dart
// Internal only — never part of the public barrel
final _huwiyaConfigProvider         = Provider<HuwiyaConfig>(...);
final _secureStorageServiceProvider = Provider<SecureStorageService>(...);
final _dioClientProvider            = Provider<Dio>(...);
final _tokenServiceProvider         = Provider<TokenService>(...);
final _authorizeServiceProvider     = Provider<AuthorizeService>(...);
final _refreshServiceProvider       = Provider<RefreshService>(...);
final _authStateNotifierProvider    = StateNotifierProvider<AuthStateNotifier, AuthState>(...);
```

All prefixed or scoped to make their internal-only nature clear. The `ProviderContainer`
that holds these is owned by `HuwiyaSDK` and never exposed on its public API.

---

## Phase 5 — Token Refresh & Session Keepalive

**Goal:** Proactively refresh the access token before expiry, deduplicate concurrent
refresh calls, and handle failure by signing the user out.

### 5.1 `RefreshService` (internal)

```dart
class RefreshService {
  static const _threshold = Duration(seconds: 60);

  Future<String>? _inflightRefresh; // deduplication guard

  Future<String> getAccessToken() async {
    final stored = await _storage.readTokens();
    if (stored == null) throw HuwiyaAuthException('No active session.');

    final nearExpiry = stored.expiresAt.isBefore(DateTime.now().add(_threshold));
    if (!nearExpiry) return stored.accessToken;

    _inflightRefresh ??= _doRefresh().whenComplete(() => _inflightRefresh = null);
    return _inflightRefresh!;
  }
}
```

All callers of `getAccessToken()` awaiting during an in-flight refresh share the same
`Future` — only one HTTP call is made regardless of how many concurrent callers exist.

### 5.2 Refresh Token Exchange

POST `{baseUrl}/oauth/token`, body:

```
grant_type=refresh_token
refresh_token={storedRefreshToken}
client_id={clientId}
```

On success:
1. Validate new JWT claims (reuse `TokenService._validateClaims`).
2. `SecureStorageService.saveTokens(newToken)`.
3. `notifier.setAuthenticated(newUser)`.
4. Return new `accessToken`.

On failure (4xx, network, claims invalid):
1. `SecureStorageService.clearTokens()`.
2. `notifier.setError(typedException)` then `notifier.setUnauthenticated()`.
3. Rethrow typed exception to the original caller.

### 5.3 `HuwiyaSDK.signOut()`

1. `SecureStorageService.clearTokens()`.
2. `notifier.setUnauthenticated()`.
3. Cancel / discard any in-flight refresh (set `_inflightRefresh = null`).

### 5.4 `HuwiyaSDK.signIn()` — Full Wiring

```
signIn()
  → notifier.setAuthenticating()
  → AuthorizeService.authorize()           // Phase 2: PKCE + browser → code
      [on cancel]  → notifier.setUnauthenticated(); rethrow UserCancelledException
      [on error]   → notifier.setError(e); rethrow
  → TokenService.exchange(code, verifier)  // Phase 3: POST /oauth/token
      [on error]   → notifier.setError(e); rethrow
  → TokenService._validateClaims()         // Phase 3: JWT validation
      [on failure] → notifier.setError(e); rethrow  (tokens never stored)
  → SecureStorageService.saveTokens()      // Phase 3: persist
  → notifier.setAuthenticated(user)        // stream pushes Authenticated to all listeners
```

### 5.5 Dio Auth Interceptor (added in Phase 5)

A `QueuedInterceptorsWrapper` added to the Dio instance:

```dart
onRequest: (options, handler) async {
  try {
    final token = await _refreshService.getAccessToken();
    options.headers['Authorization'] = 'Bearer $token';
  } on HuwiyaAuthException {
    // No session — let the request proceed without a header; server will 401.
  }
  handler.next(options);
}
```

---

## Phase Order Summary

| Phase | Scope | Depends On |
|---|---|---|
| 1 | Foundation — pubspec, layout, config, models, exceptions, SDK skeleton | nothing |
| 2 | PKCE + authorize flow (browser, redirect, CSRF check) | Phase 1 |
| 3 | Token exchange, JWT validation, secure storage, session restoration | Phase 1, 2 |
| 4 | Reactive state — sealed `AuthState`, internal notifier, public `Stream<AuthState>` | Phase 1, 3 |
| 5 | Token refresh, deduplication, `getAccessToken()`, full `signIn`/`signOut` wiring, Dio auth interceptor | Phase 1–4 |

---

## Public Barrel Export (`lib/huwiya_sdk.dart`)

Only these symbols are exported. `sdk_providers.dart` is **not** in this list.

```dart
export 'src/core/huwiya_sdk_core.dart';   // HuwiyaSDK
export 'src/core/huwiya_config.dart';     // HuwiyaConfig
export 'src/models/huwiya_user.dart';     // HuwiyaUser
export 'src/auth/auth_state.dart';        // AuthState + all variants
export 'src/exceptions/huwiya_exceptions.dart'; // all typed exceptions
```

No Riverpod type appears anywhere in this list.

---

## Final Step — Cleanup & pub.dev README

After all phases are implemented and verified:

1. Delete the `docs/` folder entirely.
2. Rewrite `README.md` as the pub.dev integration guide (see README for full content).
3. Update `CHANGELOG.md` with a `0.1.0` entry.
4. Verify `pubspec.yaml` metadata (description, homepage, repository, topics).
