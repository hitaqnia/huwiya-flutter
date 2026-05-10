/// Huwiya Flutter SDK — OAuth 2.0 + PKCE authentication for Flutter apps.
///
/// Initialize the SDK once at app startup with [HuwiyaSDK.initialize], then
/// access the singleton from anywhere via [HuwiyaSDK.instance].
///
/// See the README for end-to-end examples.
library;

export 'src/core/huwiya_sdk_core.dart';
export 'src/core/huwiya_config.dart';
export 'src/models/huwiya_user.dart';
export 'src/auth/auth_state.dart';
export 'src/exceptions/huwiya_exceptions.dart';
export 'src/providers/sdk_providers.dart';
