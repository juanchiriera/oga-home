# Oga - housekeeper

La app usa el proyecto Firebase **`oga-home`** (ver [`.firebaserc`](../../.firebaserc) en la raíz del monorepo). Los archivos nativos de configuración están versionados; para Google Sign-In en Android hace falta registrar huellas en la consola (pasos abajo).

<a id="firebase-apps-moviles-cli"></a>

## Firebase (apps móviles + CLI)

Identificadores registrados en Firebase para esta app:

| Plataforma | Uso | Package / bundle ID |
|------------|-----|----------------------|
| Android | prod | `ar.craftr.oga` |
| Android | dev | `ar.craftr.oga.dev` |
| Android | stg | `ar.craftr.oga.stg` |
| iOS | todos los flavors (mismo bundle) | `ar.craftr.oga` |

Archivos en el repo:

- Android: `android/app/src/{dev,stg,prod}/google-services.json` (mismo contenido: tres clientes Android del proyecto).
- iOS: `ios/Runner/GoogleService-Info.plist` (app iOS `ar.craftr.oga`).
- Dart: `lib/firebase_options.dart` (opciones por plataforma; podés regenerarlas con [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) si preferís).

### Regenerar `google-services.json` con la Firebase CLI

Con [Firebase CLI](https://firebase.google.com/docs/cli) instalada y sesión iniciada (`firebase login`), desde el directorio **`apps/mobile`** (los paths son relativos a ahí):

```bash
cd apps/mobile

# Listar apps del proyecto
firebase apps:list --project oga-home

# Descargar JSON de Android (usá cualquier app ID Android del listado; el JSON trae todos los clientes del proyecto)
firebase apps:sdkconfig ANDROID 1:662650052724:android:857d66273bc2cfdbd03121 \
  --project oga-home -o /tmp/google-services.json

# Opcional: quedarte solo con los paquetes ar.craftr.oga* (como en el repo; requiere `jq` instalado)
jq '.client |= map(select((.client_info.android_client_info.package_name // "") | test("^ar\\.craftr\\.oga")))' \
  /tmp/google-services.json > /tmp/google-services-filtered.json

# Copiar a los tres flavors
cp /tmp/google-services-filtered.json android/app/src/dev/google-services.json
cp /tmp/google-services-filtered.json android/app/src/stg/google-services.json
cp /tmp/google-services-filtered.json android/app/src/prod/google-services.json
```

Descargar **GoogleService-Info.plist** (reemplazá el `appId` iOS por el de `firebase apps:list` → fila **Oga iOS**):

```bash
cd apps/mobile
firebase apps:sdkconfig IOS 1:662650052724:ios:dc4dd91abfe2ae66d03121 \
  --project oga-home -o ios/Runner/GoogleService-Info.plist
```

Crear **apps nuevas** en el mismo proyecto (solo si agregás otro package o bundle; podés lanzarlos desde cualquier directorio):

```bash
firebase apps:create ANDROID "Oga Android prod" --package-name=ar.craftr.oga --project oga-home --non-interactive
firebase apps:create ANDROID "Oga Android dev" --package-name=ar.craftr.oga.dev --project oga-home --non-interactive
firebase apps:create ANDROID "Oga Android stg" --package-name=ar.craftr.oga.stg --project oga-home --non-interactive
firebase apps:create IOS "Oga iOS" --bundle-id=ar.craftr.oga --project oga-home --non-interactive
```

### Pasos que no se pueden automatizar desde acá (hacelos vos)

1. **Borrar las apps Firebase viejas** (`craftr_mobile` en Android e iOS) para no duplicar OAuth ni confundir métricas: [Firebase Console](https://console.firebase.google.com/) → proyecto **oga-home** → engranaje **Project settings** → pestaña **Your apps** → cada app con nombre `craftr_mobile` → **Remove app** (o el flujo equivalente). La CLI actual no expone `firebase apps:delete` de forma útil; es acción de consola.
2. **SHA-1 / SHA-256 por app Android** (Google Sign-In): en Firebase ya están dadas de alta (vía `firebase apps:android:sha:create`) la **SHA-1** y **SHA-256** del keystore de debug usado en el entorno donde se ejecutó el alta (`~/.android/debug.keystore`, alias `androiddebugkey`). Ese archivo es **distinto en cada PC**; otro desarrollador tiene que obtener las suyas con `keytool` o `./gradlew signingReport` y registrarlas igual (consola o CLI). Ejemplo de huellas en hex **sin dos puntos** (como pide la CLI), solo como referencia del entorno que generó el commit:
   - **SHA-1:** `54224d3beb2482980f5bc6e839acf6054a8995a3`
   - **SHA-256:** `55000113a30883262af3d01853ca2655b10d80ac98db7c71bfe63b29dfbca106`  
   Comandos de ejemplo (`appId` de **Oga Android dev**; reemplazá por prod/stg si hace falta):

   ```bash
   firebase apps:android:sha:create 1:662650052724:android:b6996921d350e763d03121 \
     54224d3beb2482980f5bc6e839acf6054a8995a3 --project oga-home --non-interactive
   firebase apps:android:sha:create 1:662650052724:android:b6996921d350e763d03121 \
     55000113a30883262af3d01853ca2655b10d80ac98db7c71bfe63b29dfbca106 --project oga-home --non-interactive
   ```

   Listar huellas: `firebase apps:android:sha:list <appIdAndroid> --project oga-home`.  
   Obtener huellas locales: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android` o `cd android && ./gradlew signingReport` (desde `apps/mobile`).
3. **Release / Play Store:** cuando firmes release con otro keystore, agregá su SHA-1 y SHA-256 a la app **Oga Android prod** en Firebase (consola o `firebase apps:android:sha:create` con el `appId` de prod).
4. **Google Cloud Console** (mismo proyecto GCP detrás de `oga-home`): si usás APIs restringidas por clave o pantallas de consentimiento OAuth, revisá que los **Client IDs** sigan alineados tras borrar apps viejas.
5. **Apple Developer / App Store Connect**: el bundle **ar.craftr.oga** tiene que existir en el identificador de la app / perfil de aprovisionamiento que uses para firmar; no es algo que la Firebase CLI resuelva.
6. **Google Play Console**: el `applicationId` publicado en la tienda debe coincidir con el de la app Firebase que uses en prod (`ar.craftr.oga` si es un único listado).
7. **RevenueCat, App Check, dominios autorizados**, etc.: donde hayas pegado el bundle o el package anterior, actualizalo a **`ar.craftr.oga`** / **`ar.craftr.oga.dev`** según entorno.

## RevenueCat (entorno dev)

1. En [RevenueCat](https://app.revenuecat.com/) → **Project settings → API keys**, copiá las claves públicas de **Google Play** y **App Store** del proyecto que usás para dev (o una sola clave `test_...` de Test Store para sandbox rápido).
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

Referencias que ya dejamos listas por MCP en este proyecto:

- Offering actual: `default` (current).
- Entitlement para uso futuro de feature flags: `premium` (adjunto a `monthly` y `yearly`).

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
