import 'package:craftr_mobile/core/revenuecat_config.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  bool get isConfigured => RevenueCatConfig.isConfigured;

  Future<void> logIn(String appUserId) async {
    if (!isConfigured) {
      return;
    }
    try {
      final result = await Purchases.logIn(appUserId);
      _logCustomerInfo('logIn', result.customerInfo);
    } catch (error, stackTrace) {
      debugPrint('RevenueCat logIn failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> logOut() async {
    if (!isConfigured) {
      return;
    }
    try {
      final customerInfo = await Purchases.logOut();
      _logCustomerInfo('logOut', customerInfo);
    } catch (error, stackTrace) {
      debugPrint('RevenueCat logOut failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<Offerings?> fetchOfferings() async {
    if (!isConfigured) {
      return null;
    }
    try {
      final offerings = await Purchases.getOfferings();
      final customerInfo = await Purchases.getCustomerInfo();
      _logCustomerInfo('fetchOfferings', customerInfo);
      return offerings;
    } catch (error, stackTrace) {
      debugPrint('RevenueCat offerings fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  void _logCustomerInfo(String source, CustomerInfo customerInfo) {
    debugPrint(
      'RevenueCat $source customerInfo: originalAppUserId='
      '${customerInfo.originalAppUserId}, activeEntitlements='
      '${customerInfo.entitlements.active.keys.toList()}',
    );
  }
}
