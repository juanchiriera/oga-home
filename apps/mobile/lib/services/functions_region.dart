import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

/// Misma región que Cloud Functions (`functions/src/index.ts`).
FirebaseFunctions craftrFunctions() =>
    FirebaseFunctions.instanceFor(region: 'southamerica-east1');

/// HTTPS Function [familyAssistantChatStream] (NDJSON, chunks de texto).
String familyAssistantStreamUrl() {
  final projectId = Firebase.app().options.projectId;
  if (projectId.isEmpty) {
    throw StateError('Firebase projectId not configured');
  }
  return 'https://southamerica-east1-$projectId.cloudfunctions.net/familyAssistantChatStream';
}
