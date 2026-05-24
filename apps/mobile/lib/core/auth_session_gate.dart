import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:oga/core/auth_bootstrap.dart';
import 'package:oga/services/auth_session_store.dart';

/// Tracks whether persisted auth has been resolved and mirrors [FirebaseAuth] updates.
class AuthSessionGate extends ChangeNotifier {
  AuthSessionGate({
    FirebaseAuth? auth,
    AuthSessionStore? sessionStore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _store = sessionStore ?? SecureAuthSessionStore();

  final FirebaseAuth _auth;
  final AuthSessionStore _store;

  bool _isReady = false;
  bool _isLoggedIn = false;

  bool get isAuthReady => _isReady;
  bool get isLoggedIn => _isLoggedIn;

  StreamSubscription<User?>? _authSub;

  Future<void> bootstrap() async {
    final user = await bootstrapAuthSession(auth: _auth, store: _store);
    _isLoggedIn = user != null;
    _isReady = true;
    notifyListeners();

    await _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user != null) {
      await _store.saveUid(user.uid);
      _isLoggedIn = true;
    } else {
      await _store.clear();
      _isLoggedIn = false;
    }
    if (_isReady) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    super.dispose();
  }
}
