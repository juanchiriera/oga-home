import 'package:oga/features/assistant/active_conversation_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocalStore implements LocalActiveConversationStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> get({required String uid, required String familyId}) async {
    return _store['$uid:$familyId'];
  }

  @override
  Future<void> set({
    required String uid,
    required String familyId,
    required String? conversationId,
  }) async {
    final key = '$uid:$familyId';
    if (conversationId == null) {
      _store.remove(key);
      return;
    }
    _store[key] = conversationId;
  }
}

class _FakeRemoteStore implements RemoteActiveConversationStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> get({required String uid, required String familyId}) async {
    return _store['$uid:$familyId'];
  }

  @override
  Future<void> set({
    required String uid,
    required String familyId,
    required String? conversationId,
  }) async {
    final key = '$uid:$familyId';
    if (conversationId == null) {
      _store.remove(key);
      return;
    }
    _store[key] = conversationId;
  }
}

class _FakeThreadsStore implements AssistantConversationThreadsStore {
  _FakeThreadsStore(this._threadsByFamily);

  final Map<String, List<String>> _threadsByFamily;
  int _createdCounter = 0;

  @override
  Future<String> create({
    required String familyId,
    required String uid,
    required String cause,
  }) async {
    final id = 'new-thread-${_createdCounter++}';
    _threadsByFamily.putIfAbsent(familyId, () => []);
    _threadsByFamily[familyId]!.insert(0, id);
    return id;
  }

  @override
  Future<bool> exists({
    required String familyId,
    required String conversationId,
  }) async {
    return _threadsByFamily[familyId]?.contains(conversationId) ?? false;
  }

  @override
  Future<String?> mostRecent({required String familyId}) async {
    final threads = _threadsByFamily[familyId];
    if (threads == null || threads.isEmpty) return null;
    return threads.first;
  }
}

void main() {
  const uid = 'u-1';
  const familyId = 'fam-1';

  test('bootstrap prioriza conversación local válida', () async {
    final local = _FakeLocalStore();
    await local.set(uid: uid, familyId: familyId, conversationId: 'local-1');
    final remote = _FakeRemoteStore();
    await remote.set(uid: uid, familyId: familyId, conversationId: 'remote-1');
    final threads = _FakeThreadsStore({
      familyId: ['local-1', 'remote-1', 'latest-1'],
    });
    final resolver = ActiveConversationResolver(
      localStore: local,
      remoteStore: remote,
      threadsStore: threads,
    );

    final active = await resolver.bootstrap(uid: uid, familyId: familyId);

    expect(active, 'local-1');
    expect(await remote.get(uid: uid, familyId: familyId), 'local-1');
  });

  test('bootstrap usa remoto cuando local no existe', () async {
    final local = _FakeLocalStore();
    await local.set(
      uid: uid,
      familyId: familyId,
      conversationId: 'stale-local',
    );
    final remote = _FakeRemoteStore();
    await remote.set(uid: uid, familyId: familyId, conversationId: 'remote-1');
    final threads = _FakeThreadsStore({
      familyId: ['remote-1', 'latest-1'],
    });
    final resolver = ActiveConversationResolver(
      localStore: local,
      remoteStore: remote,
      threadsStore: threads,
    );

    final active = await resolver.bootstrap(uid: uid, familyId: familyId);

    expect(active, 'remote-1');
    expect(await local.get(uid: uid, familyId: familyId), 'remote-1');
  });

  test(
    'bootstrap usa último chat cuando no hay id persistido válido',
    () async {
      final local = _FakeLocalStore();
      final remote = _FakeRemoteStore();
      final threads = _FakeThreadsStore({
        familyId: ['latest-1', 'old-1'],
      });
      final resolver = ActiveConversationResolver(
        localStore: local,
        remoteStore: remote,
        threadsStore: threads,
      );

      final active = await resolver.bootstrap(uid: uid, familyId: familyId);

      expect(active, 'latest-1');
      expect(await local.get(uid: uid, familyId: familyId), 'latest-1');
      expect(await remote.get(uid: uid, familyId: familyId), 'latest-1');
    },
  );

  test(
    'ensureStillValid cae a otro chat existente cuando borran el activo',
    () async {
      final local = _FakeLocalStore();
      await local.set(
        uid: uid,
        familyId: familyId,
        conversationId: 'deleted-1',
      );
      final remote = _FakeRemoteStore();
      await remote.set(
        uid: uid,
        familyId: familyId,
        conversationId: 'deleted-1',
      );
      final threads = _FakeThreadsStore({
        familyId: ['fallback-1', 'older-1'],
      });
      final resolver = ActiveConversationResolver(
        localStore: local,
        remoteStore: remote,
        threadsStore: threads,
      );

      final active = await resolver.ensureStillValid(
        uid: uid,
        familyId: familyId,
        currentConversationId: 'deleted-1',
      );

      expect(active, 'fallback-1');
      expect(await local.get(uid: uid, familyId: familyId), 'fallback-1');
      expect(await remote.get(uid: uid, familyId: familyId), 'fallback-1');
    },
  );

  test(
    'startNewConversation crea y persiste el nuevo chat explícito',
    () async {
      final local = _FakeLocalStore();
      final remote = _FakeRemoteStore();
      final threads = _FakeThreadsStore({familyId: []});
      final resolver = ActiveConversationResolver(
        localStore: local,
        remoteStore: remote,
        threadsStore: threads,
      );

      final active = await resolver.startNewConversation(
        uid: uid,
        familyId: familyId,
      );

      expect(active, startsWith('new-thread-'));
      expect(await local.get(uid: uid, familyId: familyId), active);
      expect(await remote.get(uid: uid, familyId: familyId), active);
    },
  );
}
