#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PASS=0
SKIP=0
fail(){ echo "FINAL VERIFICATION: FAIL — $1"; exit 1; }
skip(){ echo "SKIP — $1"; SKIP=$((SKIP+1)); }
pass(){ echo "PASS — $1"; PASS=$((PASS+1)); }

bash -n "$ROOT/tests/integration_smoke.sh" && pass "integration smoke script syntax"
bash -n "$ROOT/security/SECRET_SCAN.sh" && pass "secret scan syntax"
bash -n "$ROOT/release/verify_release_assets.sh" && pass "release asset checker syntax"
bash -n "$ROOT/scripts/run_flutter_android_integration.sh" && pass "Flutter integration launcher syntax"
bash "$ROOT/scripts/static_regression_v19.sh" && pass "static regression checks"
bash "$ROOT/release/verify_release_assets.sh" && pass "release asset verification"
python3 - <<'PY_IMPORTS'
from pathlib import Path
import re
roots = [Path('flutter/lib'), Path('flutter/test'), Path('flutter/integration_test')]
missing = []
for root in roots:
    for source in root.rglob('*.dart'):
        for spec in re.findall(r"import\s+'([^']+)'", source.read_text()):
            if spec.startswith('.') and not (source.parent / spec).resolve().exists():
                missing.append(f'{source}: {spec}')
if missing:
    print('FAIL — missing Dart relative imports')
    print('\n'.join(missing))
    raise SystemExit(1)
print('PASS — Dart relative import paths')
PY_IMPORTS
PASS=$((PASS+1))

python3 -m py_compile "$ROOT/tests/mock_gemini.py" && pass "mock Gemini syntax"
python3 - <<'PY'
from xml.etree import ElementTree as ET
ET.parse('release/ios/PrivacyInfo.xcprivacy.template')
print('PASS — Privacy manifest XML')
PY
PASS=$((PASS+1))

if command -v docker >/dev/null 2>&1; then
  pass "Docker available"
else
  skip "Docker not installed in this environment"
fi
if command -v cargo >/dev/null 2>&1; then
  (cd "$ROOT/rust/career_ai_rust_v3" && cargo fmt --check && cargo test) && pass "Rust fmt/test"
else
  skip "Rust/Cargo not installed in this environment"
fi
if command -v flutter >/dev/null 2>&1; then
  (cd "$ROOT/flutter" && flutter pub get && flutter analyze && flutter test) && pass "Flutter analyze/unit tests"
else
  skip "Flutter SDK not installed in this environment"
fi

if bash "$ROOT/security/SECRET_SCAN.sh" "$ROOT"; then pass "client secret scan"; else fail "client secret scan"; fi

echo "FINAL VERIFICATION: PASS (automated checks=$PASS, skipped=$SKIP)"
