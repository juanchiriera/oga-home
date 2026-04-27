import 'package:flutter/foundation.dart';

/// RevenueCat: el arranque del SDK queda gobernado por `MonetizationConfig`
/// (`lib/core/monetization.dart`, flag `BILLING_LIVE`).
///
/// Claves públicas vía `--dart-define=REVENUECAT_ANDROID_API_KEY=...`
/// y `REVENUECAT_IOS_API_KEY=...`.
/// En sandbox (Test Store) también se puede usar una sola clave:
/// `--dart-define=REVENUECAT_API_KEY=test_...`
///
/// En **debug** no hay fallback embebido: para DEV usá `./scripts/run_dev.sh`
/// tras copiar [config/dev/revenuecat.keys.sh.example] a `revenuecat.keys.sh`.
/// En **release** hay que pasar las claves por dart-define o CI.
class RevenueCatConfig {
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );
  static const String _sharedApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
  );

  static String? get apiKey {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_androidApiKey.isNotEmpty) {
        return _androidApiKey;
      }
      return _sharedApiKey.isNotEmpty ? _sharedApiKey : null;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosApiKey.isNotEmpty) {
        return _iosApiKey;
      }
      return _sharedApiKey.isNotEmpty ? _sharedApiKey : null;
    }
    return null;
  }

  static bool get isConfigured => apiKey != null;
}
