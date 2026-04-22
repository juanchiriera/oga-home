/// Firebase **project id** (público) por entorno — sin API keys en el repo.
///
/// Uso:
/// `flutter run --flavor dev --dart-define=FLAVOR=dev --dart-define=FIREBASE_PROJECT_ID=tu-proyecto-dev`
class FirebaseProject {
  const FirebaseProject._();

  static String get projectId {
    const id = String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: '',
    );
    return id;
  }

  static bool get isConfigured => projectId.isNotEmpty;
}
