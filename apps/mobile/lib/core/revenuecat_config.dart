import 'package:flutter/foundation.dart';

/// RevenueCat public SDK keys injected through dart-define.
class RevenueCatConfig {
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );

  static String? get apiKey {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _androidApiKey.isEmpty ? null : _androidApiKey;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _iosApiKey.isEmpty ? null : _iosApiKey;
    }
    return null;
  }

  static bool get isConfigured => apiKey != null;
}
