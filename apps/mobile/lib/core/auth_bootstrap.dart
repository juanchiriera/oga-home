import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:oga/services/auth_session_store.dart';

/// Waits until Firebase Auth has finished restoring any persisted native session.
Future<User?> resolveInitialAuthUser(FirebaseAuth auth) async {
  final immediate = auth.currentUser;
  if (immediate != null) {
    return immediate;
  }

  final completer = Completer<User?>();
  late final StreamSubscription<User?> subscription;
  var sawNull = false;

  subscription = auth.authStateChanges().listen((user) {
    if (user != null) {
      if (!completer.isCompleted) {
        completer.complete(user);
      }
      unawaited(subscription.cancel());
      return;
    }
    if (!sawNull) {
      sawNull = true;
      return;
    }
    if (!completer.isCompleted) {
      completer.complete(null);
    }
    unawaited(subscription.cancel());
  });

  try {
    return await completer.future.timeout(
      const Duration(milliseconds: 900),
      onTimeout: () {
        unawaited(subscription.cancel());
        return auth.currentUser;
      },
    );
  } finally {
    if (!completer.isCompleted) {
      await subscription.cancel();
    }
  }
}

/// Restores Firebase Auth, syncs [store], and returns the signed-in user if any.
Future<User?> bootstrapAuthSession({
  required FirebaseAuth auth,
  required AuthSessionStore store,
}) async {
  final user = await resolveInitialAuthUser(auth);
  if (user != null) {
    await store.saveUid(user.uid);
    return user;
  }
  await store.clear();
  return null;
}
