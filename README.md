# Huwiya Flutter SDK

OAuth 2.0 + PKCE authentication for Flutter apps, backed by Huwiya ID.

## Features

- OAuth 2.0 Authorization Code flow with PKCE (S256)
- Automatic token refresh with in-flight request deduplication
- Session restore on app launch
- JWT claims validation (`iss`, `aud`, `exp`, `iat`, plus Huwiya-specific claims)
- Reactive [`AuthState`](#reactive-auth-state) stream — works with any state
  management approach
- First-class Riverpod providers
- Tokens stored in `flutter_secure_storage` (Keychain / EncryptedSharedPreferences)
- Typed exception hierarchy

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  huwiya_sdk: ^0.1.0
```

Then run:

```sh
flutter pub get
```

---

## Platform Setup

### Android

In `android/app/src/main/AndroidManifest.xml`, add an intent filter inside your
`<activity>` tag to capture the redirect URI after authentication:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="com.example.app" />
</intent-filter>
```

Replace `com.example.app` with your own redirect URI scheme.

### iOS

In `ios/Runner/Info.plist`, register your custom URL scheme:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.example.app</string>
    </array>
  </dict>
</array>
```

---

## Initialization

Initialize the SDK once at app startup, before `runApp`. If any required config
value is missing or malformed, `initialize` throws a `HuwiyaConfigException`
immediately so you catch misconfiguration at startup rather than at runtime.

```dart
import 'package:flutter/material.dart';
import 'package:huwiya_sdk/huwiya_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sdk = await HuwiyaSDK.initialize(
    HuwiyaConfig(
      baseUrl:     'https://id.example.com',
      projectId:   'my-project-id',
      clientId:    'my-client-id',
      redirectUri: 'com.example.app://auth/callback',
      scopes:      ['openid', 'profile'],
    ),
  );

  runApp(MyApp(sdk: sdk));
}
```

After initialization, you can also reach the instance anywhere via:

```dart
final sdk = HuwiyaSDK.instance;
```

> Calling `HuwiyaSDK.instance` before `initialize` throws `StateError`.

---

## Reactive Auth State

The SDK exposes a broadcast `Stream<AuthState>` with five variants:

| Variant | Meaning |
|---|---|
| `Unauthenticated` | No active session |
| `Authenticating` | Sign-in flow is in progress |
| `Authenticated(user)` | Valid session; carries a `HuwiyaUser` |
| `Refreshing(user)` | Background token refresh; session is still valid |
| `AuthError(error)` | A typed `HuwiyaException` occurred |

Consume the stream with whichever approach fits your app:

### Plain Flutter — `StreamBuilder`

No dependencies beyond the SDK itself:

```dart
StreamBuilder<AuthState>(
  stream: HuwiyaSDK.instance.authStateStream,
  builder: (context, snapshot) {
    final state = snapshot.data ?? const Unauthenticated();
    return switch (state) {
      Unauthenticated()          => SignInButton(),
      Authenticating()           => const CircularProgressIndicator(),
      Authenticated(:final user) => Text('Hello, ${user.name}!'),
      Refreshing(:final user)    => Text('Hello, ${user.name}! (refreshing…)'),
      AuthError(:final error)    => Text('Error: ${error.message}'),
    };
  },
)
```

### Riverpod

```dart
// Define this provider once, anywhere in your app:
final authStateProvider = StreamProvider<AuthState>(
  (ref) => HuwiyaSDK.instance.authStateStream,
);

// In a ConsumerWidget:
final state = ref.watch(authStateProvider).valueOrNull ?? const Unauthenticated();
```

### Bloc

```dart
// Inside your AuthBloc constructor:
_subscription = HuwiyaSDK.instance.authStateStream.listen(
  (state) => add(AuthStateChanged(state)),
);
```

### GetX

```dart
// Inside a GetxController:
final authState = Rx<AuthState>(const Unauthenticated());

@override
void onInit() {
  super.onInit();
  HuwiyaSDK.instance.authStateStream.listen((s) => authState.value = s);
}
```

### Provider

```dart
StreamProvider<AuthState>(
  create: (_) => HuwiyaSDK.instance.authStateStream,
  initialData: const Unauthenticated(),
)
```

---

## Synchronous Snapshot

When you need the current user without subscribing to the stream (e.g. inside a
button callback), use the synchronous getter:

```dart
final user = HuwiyaSDK.instance.currentUser; // HuwiyaUser? — null if unauthenticated
```

---

## Sign In

```dart
try {
  await HuwiyaSDK.instance.signIn();
  // The authStateStream will emit Authenticated(user) on success.
} on UserCancelledException {
  // User closed the browser — no action required.
} on HuwiyaException catch (e) {
  print('Sign-in failed: ${e.message}');
}
```

---

## Sign Out

```dart
await HuwiyaSDK.instance.signOut();
// The authStateStream will emit Unauthenticated().
```

---

## Getting a Valid Access Token

The SDK refreshes tokens automatically when they are close to expiry. Use this
method when you need to attach a token to your own HTTP client:

```dart
try {
  final token = await HuwiyaSDK.instance.getAccessToken();
  // Use token as a Bearer header value.
} on HuwiyaAuthException {
  // No active session — redirect to sign-in.
}
```

Concurrent calls during an in-flight refresh are deduplicated — only one network
request is made regardless of how many callers are waiting.

---

## Error Handling

All SDK errors extend `HuwiyaException`. Catch the specific type you care about,
or catch the base type as a fallback:

| Exception | Thrown when |
|---|---|
| `HuwiyaConfigException` | `HuwiyaConfig` is missing or malformed at init |
| `UserCancelledException` | User closed the browser during sign-in |
| `ProviderException` | Huwiya ID returned an `error` in the redirect |
| `StateMismatchException` | CSRF `state` parameter did not match |
| `MissingParametersException` | Redirect was missing `code` or `state` |
| `HuwiyaTokenException` | Network failure during token exchange or refresh |
| `TokenErrorResponseException` | Token endpoint returned a 4xx error body |
| `HuwiyaClaimsException` | JWT claims validation failed (which claim + reason included) |
| `HuwiyaStorageException` | Secure storage read/write failure |

```dart
try {
  await sdk.signIn();
} on UserCancelledException {
  // silent — user chose to cancel
} on ProviderException catch (e) {
  showError('Provider error: ${e.errorDescription}');
} on HuwiyaClaimsException catch (e) {
  showError('Token claim "${e.claim}" failed: ${e.reason}');
} on HuwiyaException catch (e) {
  showError(e.message);
}
```

---

## Minimal Example App

A complete working example using plain `StreamBuilder` — no additional dependencies:

```dart
import 'package:flutter/material.dart';
import 'package:huwiya_sdk/huwiya_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HuwiyaSDK.initialize(
    HuwiyaConfig(
      baseUrl:     'https://id.example.com',
      projectId:   'proj_abc123',
      clientId:    'client_xyz',
      redirectUri: 'com.example.app://auth/callback',
      scopes:      ['openid', 'profile'],
    ),
  );

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: AuthScreen());
}

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sdk = HuwiyaSDK.instance;
    return Scaffold(
      body: Center(
        child: StreamBuilder<AuthState>(
          stream: sdk.authStateStream,
          builder: (context, snapshot) {
            final state = snapshot.data ?? const Unauthenticated();
            return switch (state) {
              Unauthenticated() => ElevatedButton(
                  onPressed: () async {
                    try {
                      await sdk.signIn();
                    } on UserCancelledException {
                      // user cancelled — do nothing
                    } on HuwiyaException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  },
                  child: const Text('Sign In'),
                ),
              Authenticating() => const CircularProgressIndicator(),
              Authenticated(:final user) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Welcome, ${user.name}!'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => sdk.signOut(),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              Refreshing() => const CircularProgressIndicator(),
              AuthError(:final error) => Text(
                  'Error: ${error.message}',
                  style: const TextStyle(color: Colors.red),
                ),
            };
          },
        ),
      ),
    );
  }
}
```

A complete runnable version lives in [`example/`](example/).

---

## Contributing

Issues and pull requests are welcome at
<https://github.com/hitaqnia/huwiya-flutter>.

## License

Released under the [MIT License](LICENSE) © Hitaqnia.

