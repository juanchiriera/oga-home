/// Build-time flavor (pass `--dart-define=FLAVOR=dev|stg|prod`).
enum AppFlavor {
  dev,
  stg,
  prod;

  static AppFlavor fromEnvironment() {
    const raw = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    return AppFlavor.values.firstWhere(
      (f) => f.name == raw,
      orElse: () => AppFlavor.dev,
    );
  }

  String get displayName => switch (this) {
        AppFlavor.dev => 'Oga, the housekeeper (dev)',
        AppFlavor.stg => 'Oga, the housekeeper (stg)',
        AppFlavor.prod => 'Oga, the housekeeper',
      };
}
