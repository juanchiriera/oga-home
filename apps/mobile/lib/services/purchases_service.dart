import 'package:oga/core/monetization.dart';
import 'package:oga/core/revenuecat_config.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchasesService {
  static const premiumEntitlementId = 'premium';

  bool get isConfigured =>
      MonetizationConfig.billingLive && RevenueCatConfig.isConfigured;

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

  Future<bool> isEntitlementActive(String entitlementId) async {
    if (!isConfigured) {
      return false;
    }
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _logCustomerInfo('isEntitlementActive', customerInfo);
      return customerInfo.entitlements.active.containsKey(entitlementId);
    } catch (error, stackTrace) {
      debugPrint(
        'RevenueCat entitlement check failed for $entitlementId: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> isPremiumActive() =>
      isEntitlementActive(PurchasesService.premiumEntitlementId);

  void addCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    if (!isConfigured) {
      return;
    }
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  void removeCustomerInfoUpdateListener(CustomerInfoUpdateListener listener) {
    if (!isConfigured) {
      return;
    }
    Purchases.removeCustomerInfoUpdateListener(listener);
  }

  void _logCustomerInfo(String source, CustomerInfo customerInfo) {
    debugPrint(
      'RevenueCat $source customerInfo: originalAppUserId='
      '${customerInfo.originalAppUserId}, activeEntitlements='
      '${customerInfo.entitlements.active.keys.toList()}',
    );
  }
}
