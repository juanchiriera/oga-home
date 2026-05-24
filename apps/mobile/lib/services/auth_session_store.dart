import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the last authenticated Firebase uid for fast session hints on cold start.
abstract class AuthSessionStore {
  Future<String?> readUid();

  Future<void> saveUid(String uid);

  Future<void> clear();
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _uidKey = 'auth.session.uid';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readUid() => _storage.read(key: _uidKey);

  @override
  Future<void> saveUid(String uid) async {
    final trimmed = uid.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('uid cannot be empty');
    }
    await _storage.write(key: _uidKey, value: trimmed);
  }

  @override
  Future<void> clear() => _storage.delete(key: _uidKey);
}
