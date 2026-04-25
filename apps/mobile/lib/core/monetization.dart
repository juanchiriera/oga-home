import 'package:flutter/foundation.dart';

/// Monetización vía tiendas (RevenueCat) y límites premium (Remote Config).
///
/// Etapa actual: `billingLive` en `false` — sin SDK ni paywalls; la app queda
/// desbloqueada. Para producción: `flutter run --dart-define=BILLING_LIVE=true`
/// (y claves RevenueCat como ya documenta el proyecto).
class MonetizationConfig {
  MonetizationConfig._();

  static const bool billingLive = bool.fromEnvironment(
    'BILLING_LIVE',
    defaultValue: false,
  );

  static void logStartupPhase() {
    if (billingLive) {
      debugPrint('Monetization: BILLING_LIVE=true (RevenueCat + Remote Config).');
    } else {
      debugPrint(
        'Monetization: BILLING_LIVE=false — RevenueCat desactivado; '
        'capacidades premium locales activas.',
      );
    }
  }
}
