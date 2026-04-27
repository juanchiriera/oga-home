# craftr_mobile

Google Sign-In requiere `google-services.json` (Android) y configuración iOS; además definí `FIREBASE_*` vía `--dart-define` o reemplazá `lib/core/firebase_options.dart` con la salida de `flutterfire configure`.

## RevenueCat (entorno dev)

1. En [RevenueCat](https://app.revenuecat.com/) → **Project settings → API keys**, copiá las claves públicas de **Google Play** y **App Store** del proyecto que usás para dev.
2. `cp config/dev/revenuecat.keys.sh.example config/dev/revenuecat.keys.sh` y pegá las claves (el archivo `revenuecat.keys.sh` no se versiona).
3. Desde `apps/mobile`: `./scripts/run_dev.sh` (flavor `dev`, `BILLING_LIVE=true`, y `--dart-define` de RevenueCat si exportaste las claves).

Sin ese paso, el SDK no se configura y verás el mensaje de bootstrap en consola.

### Sandbox: suscripción y paywall de prueba

En el dashboard de RevenueCat (o con la API si tenés automatización):

1. **App**: agregá una app **Test Store** (o la app real de Play / App Store cuando tengas productos en la tienda).
2. **Producto**: creá un producto de tipo **suscripción** en ese store (en Test Store podés definir duración y precios de prueba).
3. **Entitlement**: creá uno (por ejemplo `premium`) y **asociá el producto** al entitlement.
4. **Offering**: creá un offering (por ejemplo `default`), marcá **Current**, y un **package** (`$rc_monthly`, etc.) que apunte al producto.
5. **Paywalls** (RevenueCat → *Paywalls*): creá un paywall y vinculalo al offering / packages para que `purchases_ui_flutter` pueda mostrarlo con **Pagar suscripción (sandbox)** en Inicio.

En dispositivo/emulador: cuenta de prueba de Google Play o **Sandbox** de Apple; las compras no cobran real.

Si usás el MCP de RevenueCat en Cursor, podés crear proyecto, productos Test Store, entitlements y offerings desde ahí cuando la integración MCP tenga red y API key válida.

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
