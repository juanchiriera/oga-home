import 'package:oga/app.dart';
import 'package:oga/core/app_check_bootstrap.dart';
import 'package:oga/core/entitlements_remote_config.dart';
import 'package:oga/core/monetization.dart';
import 'package:oga/core/firebase_options.dart';
import 'package:oga/core/firestore_bootstrap.dart';
import 'package:oga/core/purchases_bootstrap.dart';
import 'package:oga/services/purchases_family_billing_sync.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MonetizationConfig.logStartupPhase();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await bootstrapAppCheck();
  await bootstrapFirestore();
  await bootstrapPurchases();
  await MobileAds.instance.initialize();
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid != null) {
    await syncPurchasesAppUserWithActiveFamily(currentUid);
  }
  final entitlementsRemoteConfig = EntitlementsRemoteConfig();
  await entitlementsRemoteConfig.initialize();
  runApp(CraftrApp(entitlementsRemoteConfig: entitlementsRemoteConfig));
}
