#!/usr/bin/env bash
set -euo pipefail
API_BASE_URL="${CAREER_AI_API_BASE_URL:-http://10.0.2.2:8080}"
DEVICE_ID="${FLUTTER_DEVICE:-}"
cd "$(dirname "$0")/../flutter"
flutter pub get
if [[ -n "$DEVICE_ID" ]]; then
  flutter test integration_test/app_smoke_test.dart -d "$DEVICE_ID" --dart-define="CAREER_AI_API_BASE_URL=${API_BASE_URL}"
else
  flutter test integration_test/app_smoke_test.dart --dart-define="CAREER_AI_API_BASE_URL=${API_BASE_URL}"
fi
