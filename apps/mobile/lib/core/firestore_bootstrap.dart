import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Configura Firestore para modo offline y metadata de sync.
Future<void> bootstrapFirestore() async {
  final firestore = FirebaseFirestore.instance;
  try {
    firestore.settings = const Settings(persistenceEnabled: true);
  } catch (error, stackTrace) {
    // No bloqueamos arranque si la plataforma/sesión no permite persistence.
    debugPrint('Firestore persistence unavailable: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
