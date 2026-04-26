import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class LocalActiveConversationStore {
  Future<String?> get({required String uid, required String familyId});

  Future<void> set({
    required String uid,
    required String familyId,
    required String? conversationId,
  });
}

abstract class RemoteActiveConversationStore {
  Future<String?> get({required String uid, required String familyId});

  Future<void> set({
    required String uid,
    required String familyId,
    required String? conversationId,
  });
}

abstract class AssistantConversationThreadsStore {
  Future<bool> exists({
    required String familyId,
    required String conversationId,
  });

  Future<String?> mostRecent({required String familyId});

  Future<String> create({
    required String familyId,
    required String uid,
    required String cause,
  });
}

class SecureLocalActiveConversationStore
    implements LocalActiveConversationStore {
  SecureLocalActiveConversationStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> get({required String uid, required String familyId}) {
    return _storage.read(
      key: _key(uid: uid, familyId: familyId),
    );
  }

  @override
  Future<void> set({
    required String uid,
    required String familyId,
    required String? conversationId,
  }) async {
    final key = _key(uid: uid, familyId: familyId);
    if (conversationId == null || conversationId.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: conversationId);
  }

  String _key({required String uid, required String familyId}) {
    return 'assistant.activeConversationId.$uid.$familyId';
  }
}

class FirestoreRemoteActiveConversationStore
    implements RemoteActiveConversationStore {
  FirestoreRemoteActiveConversationStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<String?> get({required String uid, required String familyId}) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    final assistantState = data['assistantState'];
    if (assistantState is! Map<String, dynamic>) return null;
    final activeByFamily = assistantState['activeConversationByFamily'];
    if (activeByFamily is! Map<String, dynamic>) return null;
    final value = activeByFamily[familyId];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  @override
  Future<void> set({
    required String uid,
    required String familyId,
    required String? conversationId,
  }) {
    return _firestore.collection('users').doc(uid).set({
      'assistantState': {
        'activeConversationByFamily': {
          familyId: conversationId == null || conversationId.isEmpty
              ? FieldValue.delete()
              : conversationId,
        },
      },
    }, SetOptions(merge: true));
  }
}

class FirestoreAssistantConversationThreadsStore
    implements AssistantConversationThreadsStore {
  FirestoreAssistantConversationThreadsStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<bool> exists({
    required String familyId,
    required String conversationId,
  }) async {
    final snap = await _threads(familyId).doc(conversationId).get();
    return snap.exists;
  }

  @override
  Future<String?> mostRecent({required String familyId}) async {
    final snap = await _threads(
      familyId,
    ).orderBy('updatedAt', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  @override
  Future<String> create({
    required String familyId,
    required String uid,
    required String cause,
  }) async {
    final now = FieldValue.serverTimestamp();
    final doc = _threads(familyId).doc();
    await doc.set({
      'title': 'Nueva conversación',
      'createdAt': now,
      'updatedAt': now,
      'createdBy': uid,
      'createdCause': cause,
    });
    return doc.id;
  }

  CollectionReference<Map<String, dynamic>> _threads(String familyId) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('assistantThreads');
  }
}

class ActiveConversationResolver {
  ActiveConversationResolver({
    required this.localStore,
    required this.remoteStore,
    required this.threadsStore,
  });

  final LocalActiveConversationStore localStore;
  final RemoteActiveConversationStore remoteStore;
  final AssistantConversationThreadsStore threadsStore;

  Future<String?> bootstrap({
    required String uid,
    required String familyId,
  }) async {
    final local = await _validatedCandidate(
      candidate: await localStore.get(uid: uid, familyId: familyId),
      familyId: familyId,
    );
    if (local != null) {
      await _syncAll(uid: uid, familyId: familyId, conversationId: local);
      return local;
    }

    final remote = await _validatedCandidate(
      candidate: await remoteStore.get(uid: uid, familyId: familyId),
      familyId: familyId,
    );
    if (remote != null) {
      await _syncAll(uid: uid, familyId: familyId, conversationId: remote);
      return remote;
    }

    final latest = await threadsStore.mostRecent(familyId: familyId);
    if (latest == null || latest.isEmpty) return null;
    await _syncAll(uid: uid, familyId: familyId, conversationId: latest);
    return latest;
  }

  Future<String?> ensureStillValid({
    required String uid,
    required String familyId,
    required String? currentConversationId,
  }) async {
    if (currentConversationId != null &&
        currentConversationId.isNotEmpty &&
        await threadsStore.exists(
          familyId: familyId,
          conversationId: currentConversationId,
        )) {
      return currentConversationId;
    }
    final fallback = await threadsStore.mostRecent(familyId: familyId);
    await _syncAll(uid: uid, familyId: familyId, conversationId: fallback);
    return fallback;
  }

  Future<String> startNewConversation({
    required String uid,
    required String familyId,
    String cause = 'explicit_new_chat',
  }) async {
    final conversationId = await threadsStore.create(
      familyId: familyId,
      uid: uid,
      cause: cause,
    );
    await _syncAll(
      uid: uid,
      familyId: familyId,
      conversationId: conversationId,
    );
    return conversationId;
  }

  Future<void> setActiveConversation({
    required String uid,
    required String familyId,
    required String? conversationId,
  }) {
    return _syncAll(
      uid: uid,
      familyId: familyId,
      conversationId: conversationId,
    );
  }

  Future<String?> _validatedCandidate({
    required String? candidate,
    required String familyId,
  }) async {
    if (candidate == null || candidate.isEmpty) return null;
    final exists = await threadsStore.exists(
      familyId: familyId,
      conversationId: candidate,
    );
    return exists ? candidate : null;
  }

  Future<void> _syncAll({
    required String uid,
    required String familyId,
    required String? conversationId,
  }) async {
    await Future.wait<void>([
      localStore.set(
        uid: uid,
        familyId: familyId,
        conversationId: conversationId,
      ),
      remoteStore.set(
        uid: uid,
        familyId: familyId,
        conversationId: conversationId,
      ),
    ]);
  }
}
