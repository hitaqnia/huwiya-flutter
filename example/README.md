# huwiya_sdk_example

Minimal example app demonstrating sign-in, token refresh, and sign-out with
the Huwiya Flutter SDK.

## Run

```sh
cd example
flutter create .          # generates platform folders (android/, ios/, …)
flutter pub get
flutter run
```

Then edit `lib/main.dart` and replace `baseUrl`, `projectId`, `clientId`, and
`redirectUri` with your own Huwiya ID values, and update the platform manifests
to match your custom redirect scheme — see the SDK README for instructions.
