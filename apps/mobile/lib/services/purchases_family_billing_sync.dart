import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oga/core/monetization.dart';
import 'package:oga/services/purchases_service.dart';
import 'package:flutter/foundation.dart';

/// RevenueCat webhooks project billing onto `families/{app_user_id}/billing/...`.
/// The Purchases SDK app user id must match that id: the Firestore family id when
/// the user has an active household, otherwise the Firebase Auth uid.
Future<void> syncPurchasesAppUserWithActiveFamily(String firebaseUid) async {
  if (!MonetizationConfig.billingLive) {
    return;
  }
  String? activeFamilyId;
  try {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUid)
        .get();
    activeFamilyId = snap.data()?['activeFamilyId'] as String?;
  } catch (e, st) {
    debugPrint('syncPurchasesAppUserWithActiveFamily: $e');
    debugPrintStack(stackTrace: st);
  }
  final rcUserId = (activeFamilyId != null && activeFamilyId.isNotEmpty)
      ? activeFamilyId
      : firebaseUid;
  await PurchasesService().logIn(rcUserId);
}

Future<void> bindPurchasesToFamilyId(String familyId) async {
  if (!MonetizationConfig.billingLive) {
    return;
  }
  if (familyId.isEmpty) {
    return;
  }
  await PurchasesService().logIn(familyId);
}
