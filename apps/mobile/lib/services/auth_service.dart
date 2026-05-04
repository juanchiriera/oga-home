import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:oga/services/purchases_family_billing_sync.dart';
import 'package:oga/services/purchases_service.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
    PurchasesService? purchasesService,
  }) : _authOverride = firebaseAuth,
       _googleSignInOverride = googleSignIn,
       _firestoreOverride = firestore,
       _purchasesServiceOverride = purchasesService;

  final FirebaseAuth? _authOverride;
  final GoogleSignIn? _googleSignInOverride;
  final FirebaseFirestore? _firestoreOverride;
  final PurchasesService? _purchasesServiceOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn => _googleSignInOverride ?? GoogleSignIn();
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  PurchasesService get _purchasesService =>
      _purchasesServiceOverride ?? PurchasesService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

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
      await syncPurchasesAppUserWithActiveFamily(uid);
    }
    return cred;
  }

  Future<void> signOut() async {
    await _purchasesService.logOut();
    await Future.wait([_googleSignIn.signOut(), _auth.signOut()]);
  }

  Future<void> updateProfile({
    required String displayName,
    String? photoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user');
    }

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Display name cannot be empty');
    }

    final normalizedPhotoUrl = (photoUrl ?? '').trim();
    final finalPhotoUrl = normalizedPhotoUrl.isEmpty
        ? null
        : normalizedPhotoUrl;

    await user.updateDisplayName(trimmedName);
    await user.updatePhotoURL(finalPhotoUrl);
    await user.reload();

    final ref = _firestore.collection('users').doc(user.uid);
    await ref.set({
      'displayName': trimmedName,
      'photoUrl': finalPhotoUrl,
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
