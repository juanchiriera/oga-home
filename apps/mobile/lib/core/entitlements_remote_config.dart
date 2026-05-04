import 'dart:async';

import 'package:oga/core/monetization.dart';
import 'package:oga/services/purchases_service.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Entitlements remotos consumidos por la app.
class EntitlementsState {
  const EntitlementsState({
    required this.allOn,
    required this.iaAssistantEnabled,
  });

  /// Fuerza capacidades premium / entitlements vía Remote Config.
  final bool allOn;

  /// Activa la pestaña de asistente (IA) sin necesidad de `allOn`.
  final bool iaAssistantEnabled;
}

class EntitlementsRemoteConfig {
  EntitlementsRemoteConfig({
    FirebaseRemoteConfig? remoteConfig,
    PurchasesService? purchasesService,
  }) : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance,
       _purchasesService = purchasesService ?? PurchasesService();

  static const _allOnKey = 'entitlements_all_on';
  static const _iaAssistantKey = 'ia_assistant_enabled';
  final FirebaseRemoteConfig _remoteConfig;
  final PurchasesService _purchasesService;
  final ValueNotifier<EntitlementsState> state = ValueNotifier(
    const EntitlementsState(allOn: false, iaAssistantEnabled: false),
  );
  StreamSubscription<RemoteConfigUpdate>? _updatesSubscription;
  bool _customerInfoListenerRegistered = false;

  Future<void> initialize() async {
    await _remoteConfig.setDefaults({_allOnKey: false, _iaAssistantKey: false});
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(minutes: 15),
      ),
    );

    await _fetchAndApply();
    _registerCustomerInfoUpdatesListenerIfNeeded();
    _updatesSubscription ??= _remoteConfig.onConfigUpdated.listen((_) async {
      await _fetchAndApply();
    });
  }

  /// Fuerza una resincronización inmediata de entitlements.
  Future<void> refresh() async {
    await _fetchAndApply();
  }

  Future<void> _fetchAndApply() async {
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Si falla la red, mantenemos el ultimo valor activo o defaults.
    }
    await _syncState();
  }

  Future<void> _syncState() async {
    if (!MonetizationConfig.billingLive) {
      const nextState = EntitlementsState(
        allOn: true,
        iaAssistantEnabled: true,
      );
      if (state.value.allOn != nextState.allOn ||
          state.value.iaAssistantEnabled != nextState.iaAssistantEnabled) {
        state.value = nextState;
      }
      return;
    }
    final remoteAllOn = _remoteConfig.getBool(_allOnKey);
    final premiumActive = await _purchasesService.isPremiumActive();
    final nextState = EntitlementsState(
      allOn: remoteAllOn || premiumActive,
      iaAssistantEnabled: _remoteConfig.getBool(_iaAssistantKey),
    );
    if (state.value.allOn != nextState.allOn ||
        state.value.iaAssistantEnabled != nextState.iaAssistantEnabled) {
      state.value = nextState;
    }
  }

  void _registerCustomerInfoUpdatesListenerIfNeeded() {
    if (_customerInfoListenerRegistered || !_purchasesService.isConfigured) {
      return;
    }
    _purchasesService.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    _customerInfoListenerRegistered = true;
  }

  void _onCustomerInfoUpdated(dynamic _) {
    unawaited(_syncState());
  }

  Future<void> dispose() async {
    if (_customerInfoListenerRegistered) {
      _purchasesService.removeCustomerInfoUpdateListener(
        _onCustomerInfoUpdated,
      );
    }
    await _updatesSubscription?.cancel();
    state.dispose();
  }
}
