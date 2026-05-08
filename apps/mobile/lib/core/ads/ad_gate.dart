import 'package:oga/core/entitlements_scope.dart';
import 'package:oga/core/monetization.dart';
import 'package:flutter/widgets.dart';

bool shouldShowAds(BuildContext context) {
  if (!MonetizationConfig.billingLive) {
    return false;
  }
  final entitlements = MainShellEntitlementsScope.of(context);
  if (entitlements.noAds) {
    return false;
  }
  return true;
}
