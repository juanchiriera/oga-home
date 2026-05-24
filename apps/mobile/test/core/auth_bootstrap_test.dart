import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oga/core/auth_bootstrap.dart';
import 'package:oga/services/auth_session_store.dart';

class _FakeUser implements User {
  _FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth({User? currentUser, Stream<User?>? authStateChanges})
    : _currentUser = currentUser,
      _authStateChanges = (authStateChanges ?? Stream<User?>.value(currentUser))
          .asBroadcastStream();

  final User? _currentUser;
  final Stream<User?> _authStateChanges;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _authStateChanges;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryAuthSessionStore implements AuthSessionStore {
  String? _uid;

  @override
  Future<void> clear() async {
    _uid = null;
  }

  @override
  Future<String?> readUid() async => _uid;

  @override
  Future<void> saveUid(String uid) async {
    _uid = uid;
  }
}

void main() {
  group('resolveInitialAuthUser', () {
    test('devuelve currentUser inmediato si ya está restaurado', () async {
      final auth = _FakeFirebaseAuth(currentUser: _FakeUser('u1'));
      final user = await resolveInitialAuthUser(auth);
      expect(user?.uid, 'u1');
    });

    test('espera al primer evento con usuario en el stream', () async {
      final controller = StreamController<User?>();
      final auth = _FakeFirebaseAuth(authStateChanges: controller.stream);
      final future = resolveInitialAuthUser(auth);
      controller.add(_FakeUser('u2'));
      await controller.close();
      final user = await future;
      expect(user?.uid, 'u2');
    });
  });

  group('bootstrapAuthSession', () {
    test('persiste uid cuando hay sesión', () async {
      final store = _MemoryAuthSessionStore();
      final auth = _FakeFirebaseAuth(currentUser: _FakeUser('persisted'));
      final user = await bootstrapAuthSession(auth: auth, store: store);
      expect(user?.uid, 'persisted');
      expect(await store.readUid(), 'persisted');
    });

    test('limpia almacenamiento local sin sesión', () async {
      final store = _MemoryAuthSessionStore();
      await store.saveUid('stale');
      final auth = _FakeFirebaseAuth();
      final user = await bootstrapAuthSession(auth: auth, store: store);
      expect(user, isNull);
      expect(await store.readUid(), isNull);
    });
  });
}
