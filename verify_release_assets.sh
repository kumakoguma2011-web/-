#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if grep -RIn --exclude-dir=.git --exclude='*.md' --exclude='*.html' -E 'AIzaSy|x-goog-api-key|GEMINI_API_KEY[[:space:]]*=' "$ROOT/flutter" >/tmp/career_ai_secret_scan.txt 2>/dev/null; then
  echo "FAIL: possible Gemini secret in Flutter source"
  cat /tmp/career_ai_secret_scan.txt
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
from xml.etree import ElementTree as ET
p=Path('release/ios/PrivacyInfo.xcprivacy.template')
ET.parse(p)
print('PrivacyInfo.xcprivacy.template: XML OK')
PY
bash -n "$ROOT/release/verify_release_assets.sh"
echo "release asset checks: PASS"
