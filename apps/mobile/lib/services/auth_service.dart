import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:oga/core/flavor.dart';
import 'package:oga/services/auth_session_store.dart';
import 'package:oga/services/functions_region.dart';
import 'package:oga/services/purchases_family_billing_sync.dart';
import 'package:oga/services/purchases_service.dart';

/// Thrown when email/password sign-in succeeds but the address is not verified.
class EmailNotVerifiedException implements Exception {
  EmailNotVerifiedException(this.email);

  final String email;

  @override
  String toString() => 'EmailNotVerifiedException($email)';
}

enum EmailActionLinkResult {
  notHandled,
  emailVerified,
}

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    PurchasesService? purchasesService,
    AuthSessionStore? sessionStore,
  }) : _authOverride = firebaseAuth,
       _googleSignInOverride = googleSignIn,
       _firestoreOverride = firestore,
       _purchasesServiceOverride = purchasesService,
       _sessionStoreOverride = sessionStore;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleSignInOverride;
  final FirebaseFirestore? _firestoreOverride;
  final PurchasesService? _purchasesServiceOverride;
  final AuthSessionStore? _sessionStoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _googleSignInOverride ?? GoogleSignIn();
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  PurchasesService get _purchasesService =>
      _purchasesServiceOverride ?? PurchasesService();
  AuthSessionStore get _sessionStore =>
      _sessionStoreOverride ?? SecureAuthSessionStore();

  static const emailVerificationContinueUrl =
      'https://oga-home.web.app/email-verified';

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  ActionCodeSettings get _emailActionCodeSettings {
    return ActionCodeSettings(
      url: emailVerificationContinueUrl,
      handleCodeInApp: true,
      androidPackageName: _androidPackageNameForFlavor(),
      androidInstallApp: true,
      androidMinimumVersion: '21',
      iOSBundleId: 'ar.craftr.oga',
    );
  }

  String _androidPackageNameForFlavor() {
    return switch (AppFlavor.fromEnvironment()) {
      AppFlavor.dev => 'ar.craftr.oga.dev',
      AppFlavor.stg => 'ar.craftr.oga.stg',
      AppFlavor.prod => 'ar.craftr.oga',
    };
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('Google sign-in cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    await _upsertUserDocument(cred.user);
    final uid = cred.user?.uid;
    if (uid != null) {
      await _sessionStore.saveUid(uid);
      await syncPurchasesAppUserWithActiveFamily(uid);
    }
    return cred;
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    await _upsertUserDocument(cred.user);
    await cred.user?.sendEmailVerification(_emailActionCodeSettings);
    final uid = cred.user?.uid;
    if (uid != null) {
      await _sessionStore.saveUid(uid);
    }
    return cred;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final cred = await _auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    await cred.user?.reload();
    final user = _auth.currentUser;
    if (user != null &&
        userRequiresEmailVerification(user) &&
        !user.emailVerified) {
      throw EmailNotVerifiedException(trimmedEmail);
    }
    await _upsertUserDocument(user);
    final uid = user?.uid;
    if (uid != null) {
      await _sessionStore.saveUid(uid);
      await syncPurchasesAppUserWithActiveFamily(uid);
    }
    return cred;
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }
    await user.sendEmailVerification(_emailActionCodeSettings);
  }

  Future<EmailActionLinkResult> handleEmailActionLink(Uri link) async {
    if (!isFirebaseAuthActionLink(link)) {
      return EmailActionLinkResult.notHandled;
    }

    final mode = link.queryParameters['mode'];
    final oobCode = link.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) {
      return EmailActionLinkResult.notHandled;
    }

    if (mode == 'verifyEmail') {
      await _auth.applyActionCode(oobCode);
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        await _upsertUserDocument(user);
        await _sessionStore.saveUid(user.uid);
        await syncPurchasesAppUserWithActiveFamily(user.uid);
      }
      return EmailActionLinkResult.emailVerified;
    }

    return EmailActionLinkResult.notHandled;
  }

  Future<void> signOut() async {
    await _purchasesService.logOut();
    await Future.wait([
      _googleSignIn.signOut(),
      _auth.signOut(),
      _sessionStore.clear(),
    ]);
  }

  /// Purges Firestore data via [purgeAccountData], deletes the Firebase Auth user
  /// after provider-specific re-auth, and clears RevenueCat / session state.
  Future<void> deleteAccountWithReauthentication({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    if (userHasGoogleProvider(user)) {
      await _reauthenticateWithGoogle(user);
    } else if (userRequiresEmailVerification(user)) {
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw StateError('No email on account');
      }
      if (password == null || password.isEmpty) {
        throw ArgumentError('Password required for email account deletion');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } else {
      throw StateError('Unsupported auth provider');
    }

    final purge = craftrFunctions().httpsCallable('purgeAccountData');
    await purge.call<Map<String, dynamic>>({});

    await _purchasesService.logOut();
    await user.delete();
    await _googleSignIn.signOut();
    await _sessionStore.clear();
  }

  Future<void> deleteAccountWithGoogleReauthentication() async {
    await deleteAccountWithReauthentication();
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw StateError('Google sign-in cancelled');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> updateProfile({required String displayName}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Display name cannot be empty');
    }

    await user.updateDisplayName(trimmedName);
    await user.reload();

    final ref = _firestore.collection('users').doc(user.uid);
    await ref.set({
      'displayName': trimmedName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _upsertUserDocument(User? user) async {
    if (user == null) {
      return;
    }
    final ref = _firestore.collection('users').doc(user.uid);
    await ref.set({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

bool userRequiresEmailVerification(User user) {
  return user.providerData.any((info) => info.providerId == 'password');
}

bool userHasGoogleProvider(User user) {
  return user.providerData.any((info) => info.providerId == 'google.com');
}

bool isFirebaseAuthActionLink(Uri uri) {
  if (uri.queryParameters.containsKey('oobCode') &&
      uri.queryParameters.containsKey('mode')) {
    if (uri.path.contains('/__/auth/action')) {
      return true;
    }
    if (uri.host.endsWith('.firebaseapp.com') ||
        uri.host.endsWith('.web.app')) {
      return true;
    }
  }
  return false;
}
