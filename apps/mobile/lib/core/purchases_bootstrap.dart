import 'package:craftr_mobile/core/revenuecat_config.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

Future<void> bootstrapPurchases() async {
  final apiKey = RevenueCatConfig.apiKey;
  if (apiKey == null) {
    debugPrint(
      'RevenueCat bootstrap skipped: missing key for this platform.',
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
