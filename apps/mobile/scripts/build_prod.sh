#!/usr/bin/env bash
# Genera el Android App Bundle (.aab) para el flavor `prod`.
# Carga las claves de RevenueCat si el archivo existe.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_FILE="$MOBILE_ROOT/config/prod/revenuecat.keys.sh"

# Por defecto, BILLING_LIVE es true para builds de producción
BILLING_LIVE=${BILLING_LIVE:-true}

cd "$MOBILE_ROOT"

flutter_args=(
  build
  appbundle
  --flavor
  prod
  --dart-define=FLAVOR=prod
  --dart-define=BILLING_LIVE=$BILLING_LIVE
)

if [[ -f "$KEYS_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$KEYS_FILE"

  if [[ -n "${REVENUECAT_ANDROID_API_KEY:-}" ]]; then
    flutter_args+=(--dart-define="REVENUECAT_ANDROID_API_KEY=${REVENUECAT_ANDROID_API_KEY}")
  fi
  # Agregamos las otras por si acaso, aunque appbundle es para Android
  if [[ -n "${REVENUECAT_API_KEY:-}" ]]; then
    flutter_args+=(--dart-define="REVENUECAT_API_KEY=${REVENUECAT_API_KEY}")
  fi
fi

echo "Building AppBundle with BILLING_LIVE=$BILLING_LIVE..."
exec flutter "${flutter_args[@]}" "$@"
