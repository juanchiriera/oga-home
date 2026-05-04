# famil-ia / Oga - housekeeper

Monorepo: **Firebase** (`functions/`, reglas) + **Flutter** (`apps/mobile`).

## Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) (canal stable)
- Node 20+ para Cloud Functions
- Firebase CLI (opcional, para despliegue)

## Flutter (app móvil)

```bash
cd apps/mobile
flutter pub get
flutter run --flavor dev --dart-define=FLAVOR=dev
# Tras login, la app abre en /app (shell con barra inferior).
```

Flavors Android: `dev`, `stg`, `prod` (IDs `ar.craftr.oga.dev`, `ar.craftr.oga.stg`, `ar.craftr.oga` en prod).

```bash
flutter build apk --flavor prod --dart-define=FLAVOR=prod
flutter build ios --release --no-codesign --dart-define=FLAVOR=prod
```

## Monorepo (Melos)

Desde la raíz del repo:

```bash
dart pub get
dart run melos bootstrap
```

## CI

GitHub Actions ejecuta `flutter analyze` y builds en `.github/workflows/flutter_ci.yml`.

## Documentación de producto

Ver [docs/PRODUCTO_Y_BACKLOG.md](docs/PRODUCTO_Y_BACKLOG.md).

## Firebase (multi-entorno y secretos)

Ver [docs/FIREBASE_MULTIENTORNO_Y_SECRET_MANAGER.md](docs/FIREBASE_MULTIENTORNO_Y_SECRET_MANAGER.md). Sustituye los `REPLACE_ME_*` en [`.firebaserc`](.firebaserc) por tus Project IDs.

Registro de apps Android/iOS (package `ar.craftr.oga`, SHA-1, limpieza de apps viejas en la consola): [apps/mobile/README.md#firebase-apps-moviles-cli](apps/mobile/README.md#firebase-apps-moviles-cli).
