#!/usr/bin/env bash
# Ejecuta la app con flavor `dev` y, si existe, carga las claves públicas de RevenueCat.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KEYS_FILE="$MOBILE_ROOT/config/dev/revenuecat.keys.sh"

if [[ -f "$KEYS_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$KEYS_FILE"
fi

cd "$MOBILE_ROOT"

flutter_args=(
  run
  --flavor
  dev
  --dart-define=FLAVOR=dev
)

if [[ -n "${REVENUECAT_ANDROID_API_KEY:-}" ]]; then
  flutter_args+=(--dart-define="REVENUECAT_ANDROID_API_KEY=${REVENUECAT_ANDROID_API_KEY}")
fi
if [[ -n "${REVENUECAT_IOS_API_KEY:-}" ]]; then
  flutter_args+=(--dart-define="REVENUECAT_IOS_API_KEY=${REVENUECAT_IOS_API_KEY}")
fi

exec flutter "${flutter_args[@]}" "$@"
