import 'package:oga/core/monetization.dart';
import 'package:oga/core/revenuecat_config.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Future<void> bootstrapPurchases() async {
  if (!MonetizationConfig.billingLive) {
    debugPrint('RevenueCat bootstrap skipped: BILLING_LIVE=false.');
    return;
  }
  final apiKey = RevenueCatConfig.apiKey;
  if (apiKey == null) {
    debugPrint(
      'RevenueCat bootstrap skipped: missing REVENUECAT_*_API_KEY. '
      'DEV: copy apps/mobile/config/dev/revenuecat.keys.sh.example to '
      'revenuecat.keys.sh and run apps/mobile/scripts/run_dev.sh',
    );
    return;
  }

  try {
    await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration(apiKey);
    await Purchases.configure(config);
    final customerInfo = await Purchases.getCustomerInfo();
    debugPrint(
      'RevenueCat configured. Active entitlements: ${customerInfo.entitlements.active.keys.toList()}',
    );
  } catch (error, stackTrace) {
    debugPrint('RevenueCat bootstrap failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
