import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Entitlements remotos consumidos por la app.
class EntitlementsState {
  const EntitlementsState({required this.allOn});

  final bool allOn;
}

class EntitlementsRemoteConfig {
  EntitlementsRemoteConfig({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  static const _allOnKey = 'entitlements_all_on';
  final FirebaseRemoteConfig _remoteConfig;
  final ValueNotifier<EntitlementsState> state = ValueNotifier(
    EntitlementsState(allOn: false),
  );
  StreamSubscription<RemoteConfigUpdate>? _updatesSubscription;

  Future<void> initialize() async {
    await _remoteConfig.setDefaults({_allOnKey: false});
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(minutes: 15),
      ),
    );

    await _fetchAndApply();
    _updatesSubscription ??= _remoteConfig.onConfigUpdated.listen((_) async {
      await _fetchAndApply();
    });
  }

  Future<void> _fetchAndApply() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Si falla la red, mantenemos el ultimo valor activo o defaults.
    }
    _syncState();
  }

  void _syncState() {
    final nextState = EntitlementsState(
      allOn: _remoteConfig.getBool(_allOnKey),
    );
    if (state.value.allOn != nextState.allOn) {
      state.value = nextState;
    }
  }

  Future<void> dispose() async {
    await _updatesSubscription?.cancel();
    state.dispose();
  }
}
