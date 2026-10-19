#!/usr/bin/env bash
set -euo pipefail
root="${1:-.}"
if grep -RInE --exclude-dir=.git --exclude='*.zip' '(AIza[0-9A-Za-z_-]{20,}|GEMINI_API_KEY\s*=\s*[^$\{][^[:space:]]+|x-goog-api-key\s*[:=]\s*["'"'"'][^"'"'"']+)' "$root/flutter" "$root/release" 2>/dev/null; then
  echo "SECRET SCAN: FAIL"
  exit 1
fi

echo "SECRET SCAN: PASS"
