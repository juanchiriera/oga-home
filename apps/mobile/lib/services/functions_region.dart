import 'package:cloud_functions/cloud_functions.dart';

/// Misma región que Cloud Functions (`functions/src/index.ts`).
FirebaseFunctions craftrFunctions() =>
    FirebaseFunctions.instanceFor(region: 'southamerica-east1');
