import 'package:craftr_mobile/app.dart';
import 'package:craftr_mobile/core/app_check_bootstrap.dart';
import 'package:craftr_mobile/core/entitlements_remote_config.dart';
import 'package:craftr_mobile/core/firebase_options.dart';
import 'package:craftr_mobile/core/firestore_bootstrap.dart';
import 'package:craftr_mobile/core/purchases_bootstrap.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await bootstrapAppCheck();
  await bootstrapFirestore();
  await bootstrapPurchases();
  final entitlementsRemoteConfig = EntitlementsRemoteConfig();
  await entitlementsRemoteConfig.initialize();
  runApp(CraftrApp(entitlementsRemoteConfig: entitlementsRemoteConfig));
}
