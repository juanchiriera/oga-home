# craftr_mobile

Google Sign-In requiere `google-services.json` (Android) y configuración iOS; además definí `FIREBASE_*` vía `--dart-define` o reemplazá `lib/core/firebase_options.dart` con la salida de `flutterfire configure`.

## RevenueCat (entorno dev)

1. En [RevenueCat](https://app.revenuecat.com/) → **Project settings → API keys**, copiá las claves públicas de **Google Play** y **App Store** del proyecto que usás para dev.
2. `cp config/dev/revenuecat.keys.sh.example config/dev/revenuecat.keys.sh` y pegá las claves (el archivo `revenuecat.keys.sh` no se versiona).
3. Desde `apps/mobile`: `./scripts/run_dev.sh` (equivale a `flutter run --flavor dev` más los `--dart-define` de RevenueCat).

Sin ese paso, el SDK no se configura y verás el mensaje de bootstrap en consola.

Deep links soportados:

- Invitación: `craftr://invite/<token>` (Android + iOS).
- Familia + entidad: `craftr://family/<familyId>/<entityType>/<entityId>`.

Si no hay sesión iniciada y se abre un deep link, la app guarda el destino y redirige después de login.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
