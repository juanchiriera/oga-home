# Firebase multi-entorno (dev / staging / prod) y Secret Manager

Objetivo: tres proyectos GCP/Firebase (ADR-004), sin secretos en el repositorio. La app Flutter apunta a cada entorno vía `--dart-define` (IDs públicos de proyecto) y los binarios nativos usan `google-services.json` / `GoogleService-Info.plist` **no versionados** (se generan con Firebase Console o `flutterfire configure`).

## 1. Crear proyectos y apps

1. En [Firebase Console](https://console.firebase.google.com/) crea tres proyectos, por ejemplo: `craftr-dev`, `craftr-stg`, `craftr-prod`.
2. En cada proyecto habilita: **Authentication** (Google), **Firestore**, **Functions**, **Storage**, **Remote Config** (y las APIs de facturación GCP asociadas).
3. Registra apps Android/iOS/Web en cada proyecto y descarga los artefactos de configuración del cliente en rutas locales (ver §4).

## 2. Sincronizar `.firebaserc`

Sustituye los placeholders en [`.firebaserc`](../.firebaserc) por los **Project ID** reales.

Uso local:

```bash
firebase use dev     # o: firebase use staging | prod
firebase deploy --only functions,firestore:rules,storage
```

## 3. Secret Manager (GCP)

Crea secretos **por proyecto** (mismos nombres en cada uno para simplificar CI):

| Nombre sugerido            | Uso                                      |
| -------------------------- | ---------------------------------------- |
| `OPENROUTER_API_KEY`      | Llamadas OpenRouter (Chat Completions) desde Cloud Functions |
| `RC_WEBHOOK_SECRET`        | Verificación HMAC de webhooks RevenueCat |
| `RC_WEBHOOK_SIGNATURE_HEADER` | Header de firma webhook (default `X-RevenueCat-Signature`) |

Por proyecto:

```bash
gcloud config set project REPLACE_ME_CRAFTR_DEV
echo -n "valor" | gcloud secrets create OPENROUTER_API_KEY --data-file=-
# Repetir en stg/prod y otorgar acceso a la cuenta de servicio de Cloud Functions
```

En Functions v2 los secretos se declaran con `defineSecret` y se enlazan al deploy. Ejemplo:

```ts
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";

const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");

export const securePing = onRequest(
  { secrets: [openRouterApiKey] },
  (_req, res) => {
    void openRouterApiKey.value();
    res.status(200).send("ok");
  },
);
```

Despliega solo después de `firebase functions:secrets:set OPENROUTER_API_KEY` en ese proyecto.

### Parámetros de OpenRouter (no secretos)

Además de la clave, las Functions usan parámetros de entorno (Firebase **params** / `firebase functions:config` según el flujo del equipo) para el **ID de modelo** por caso de uso. Los nombres alinean la documentación con el código:

| Parámetro | Rol típico |
| --------- | ---------- |
| `OPENROUTER_RECIPE_IMPORT_MODEL` | Importación de receta desde URL (HTML) |
| `OPENROUTER_ASSISTANT_MODEL` | Asistente (chat y stream) |
| `OPENROUTER_EXPENSE_MODEL` | Sugerencia de categoría e importación con visión (ticket / resumen) |
| `OPENROUTER_HTTP_REFERER` | Opcional: URL de atribución para el dashboard de OpenRouter |
| `OPENROUTER_APP_TITLE` | Opcional: título de app en atribución (p. ej. `Famil-IA`) |

Los IDs de modelo siguen el catálogo de OpenRouter (p. ej. `openai/gpt-4o-mini`); se pueden cambiar sin conmutar de proveedor de integración. Ver [OpenRouter - Models](https://openrouter.ai/models).

### RevenueCat webhook (E3-02)

- Function: `revenuecatWebhook` (HTTPS, Functions v2).
- Firma: HMAC SHA-256 sobre `rawBody`.
- Secreto requerido: `RC_WEBHOOK_SECRET`.
- Header de firma configurable con parámetro `RC_WEBHOOK_SIGNATURE_HEADER` (si no está, usa `X-RevenueCat-Signature`).
- Idempotencia: deduplicación por `event_id` en `families/{familyId}/billingEvents/{eventId}`.
- Proyección de estado para cliente en `families/{familyId}/billing/current`.

## 4. Flutter: sin secretos en repo

- **Nunca** commitear API keys de OpenRouter (u otros proveedores de IA), tokens de RevenueCat server-side, etc.
- Variables **no sensibles** (solo identificadores de proyecto Firebase) pueden pasarse como:

```bash
flutter run --flavor dev --dart-define=FLAVOR=dev \
  --dart-define=FIREBASE_PROJECT_ID=REPLACE_ME_CRAFTR_DEV
```

- Coloca `google-services.json` (Android) y `GoogleService-Info.plist` (iOS) por flavor en rutas ignoradas por git (p. ej. `apps/mobile/config/dev/`) o usa `--dart-define` + `flutterfire configure` según el flujo del equipo.

## 5. CI: despliegue por rama

El workflow [.github/workflows/firebase_deploy.yml](../.github/workflows/firebase_deploy.yml) despliega **solo** si existen los secretos `FIREBASE_SERVICE_ACCOUNT_DEV` / `_STG` / `_PROD` (JSON en base64 o contenido del key, según cómo los configures en GitHub).

**Pendiente de cada entorno:** crear cuenta de servicio con roles mínimos (Firebase Admin o roles granulares), JSON como secret de GitHub, y ajustar el mapping rama → proyecto en el YAML.

## 6. Pipelines por rama (resumen)

| Rama sugerida | Alias Firebase | Proyecto |
| -------------- | --------------- | -------- |
| `develop`      | `dev`           | dev      |
| `staging`      | `staging`       | stg      |
| `main`         | `prod`          | prod     |

Ajusta nombres de ramas a tu flujo real antes de activar el workflow en producción.
