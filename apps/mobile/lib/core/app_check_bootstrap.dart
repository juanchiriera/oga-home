import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Registers an App Check provider so Storage and other Firebase backends
/// receive a valid token (required when App Check enforcement is enabled).
///
/// Uses [AndroidProvider.debug] / [AppleProvider.debug] for any non-release
/// build (including **profile**). `flutter run --profile` sets [kDebugMode]
/// to false, so attestation-only providers would run on emulators and return
/// 403 until Play Integrity / App Attest succeed — which they often do not
/// in dev. Release builds use real attestation.
///
/// **Debug tokens:** On first run, logcat / Xcode prints a token; register it
/// in Firebase Console → App Check → your app → Manage debug tokens.
Future<void> bootstrapAppCheck() async {
  final useAttestation = kReleaseMode;
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        useAttestation ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider:
        useAttestation ? AppleProvider.appAttest : AppleProvider.debug,
  );
}
