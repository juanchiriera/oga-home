import 'package:flutter/foundation.dart';

/// RevenueCat: claves públicas vía `--dart-define=REVENUECAT_ANDROID_API_KEY=...`
/// y `REVENUECAT_IOS_API_KEY=...`.
///
/// En **debug**, si no hay dart-define, se usa la clave de prueba del proyecto
/// (sandbox). En **release** no hay fallback: hay que pasar las claves por
/// dart-define o CI.
class RevenueCatConfig {
  static const String _androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
  );
  static const String _iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
  );

  /// Clave pública de prueba (RevenueCat test store / sandbox).
  static const String debugTestApiKey = 'test_ukOtazEbukIVAnihGhSJDfwAoaX';

  static String? get apiKey {
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_androidApiKey.isNotEmpty) {
        return _androidApiKey;
      }
      if (kDebugMode) {
        return debugTestApiKey;
      }
      return null;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosApiKey.isNotEmpty) {
        return _iosApiKey;
      }
      if (kDebugMode) {
        return debugTestApiKey;
      }
      return null;
    }
    return null;
  }

  static bool get isConfigured => apiKey != null;
}
