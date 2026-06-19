# AGENTS.md

## Cursor Cloud specific instructions

### Overview

This is a **Melos-managed monorepo** with two main services:

| Service | Path | Language | Key commands |
|---------|------|----------|-------------|
| Flutter mobile app | `apps/mobile/` | Dart | `flutter analyze`, `flutter test`, `flutter build apk --flavor dev --dart-define=FLAVOR=dev` |
| Firebase Cloud Functions | `functions/` | TypeScript (Node 20) | `npm run build` (typecheck), `npm test` (vitest unit), `npm run test:rules` (needs Firebase emulator) |

### Environment prerequisites

- **Flutter SDK** at `/opt/flutter/bin` (stable channel, Dart >=3.11.5)
- **Node.js 20** via nvm (default alias set to 20)
- **Java 17 Temurin** (`JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64`)
- **Android SDK** at `~/android-sdk` with command-line tools, platform-tools, platforms (android-35/36), build-tools

All of these are on `PATH` via `~/.bashrc`.

### Non-obvious gotchas

- The Dart SDK constraint is `^3.11.5`. Flutter stable 3.41.x bundles exactly Dart 3.11.5; do not switch to Flutter beta/dev channels.
- Android builds require Java 17 specifically (`JavaVersion.VERSION_17` in `build.gradle.kts`). The system may have Java 21 installed by default — ensure `JAVA_HOME` points to Temurin 17.
- The monorepo root `pubspec.yaml` only has `melos` as a dev dependency. Run `dart pub get` at the root, then `dart run melos bootstrap` to resolve all packages.
- Flutter app has three Android flavors: `dev`, `stg`, `prod`. Always pass `--flavor` and `--dart-define=FLAVOR=` together.
- Functions smoke tests (`npm run test:smoke`) require the `OPENROUTER_API_KEY` environment variable. Unit tests (`npm test`) run without it.
- Firestore rules tests (`npm run test:rules`) require Firebase CLI emulators to be installed and running.
- The app is localized in Spanish (es-AR). UI strings use Flutter `gen_l10n` with ARB files.
- `flutter build apk` auto-downloads missing Android SDK components (NDK, platforms, CMake) on first run via Gradle. The initial build takes ~6 minutes.
