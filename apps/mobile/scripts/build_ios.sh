#!/usr/bin/env bash
# Genera el archivo .ipa para iOS (flavor `prod`).
# Carga las claves de RevenueCat si el archivo existe.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_FILE="$MOBILE_ROOT/config/prod/revenuecat.keys.sh"

# Por defecto, BILLING_LIVE es true para builds de producción
BILLING_LIVE=${BILLING_LIVE:-true}

cd "$MOBILE_ROOT"

# Asegurarse de que los pods estén al día
echo "Installing pods..."
POD_CMD="pod"
if [[ -f "/Users/juancruzriera/.gem/ruby/2.6.0/bin/pod" ]]; then
  POD_CMD="/Users/juancruzriera/.gem/ruby/2.6.0/bin/pod"
fi

(cd ios && $POD_CMD install)

flutter_args=(
  build
  ipa
  --flavor
  prod
  --dart-define=FLAVOR=prod
  --dart-define=BILLING_LIVE=$BILLING_LIVE
)

if [[ -f "$KEYS_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$KEYS_FILE"

  if [[ -n "${REVENUECAT_IOS_API_KEY:-}" ]]; then
    flutter_args+=(--dart-define="REVENUECAT_IOS_API_KEY=${REVENUECAT_IOS_API_KEY}")
  fi
  # Alternativa compartida
  if [[ -n "${REVENUECAT_API_KEY:-}" ]]; then
    flutter_args+=(--dart-define="REVENUECAT_API_KEY=${REVENUECAT_API_KEY}")
  fi
fi

echo "Building IPA with BILLING_LIVE=$BILLING_LIVE..."
exec flutter "${flutter_args[@]}" "$@"
