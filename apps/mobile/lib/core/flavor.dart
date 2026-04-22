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
        AppFlavor.dev => 'CraftR (dev)',
        AppFlavor.stg => 'CraftR (stg)',
        AppFlavor.prod => 'CraftR',
      };
}
