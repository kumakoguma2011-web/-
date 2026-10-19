#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -q 'client_message_id' "$ROOT/rust/career_ai_rust_v3/src/main.rs"
grep -q 'client_message_id' "$ROOT/rust/career_ai_rust_v3/migrations/0003_message_idempotency.sql"
grep -q '【添付ファイル】' "$ROOT/rust/career_ai_rust_v3/src/main.rs"
grep -q 'fn address_re()' "$ROOT/rust/career_ai_rust_v3/src/lib.rs"
grep -q 'プロフィールに追加' "$ROOT/flutter/lib/features/chat/chat_screen.dart"
grep -q 'uuid:' "$ROOT/flutter/pubspec.yaml"
python3 -m py_compile "$ROOT/tests/mock_gemini.py"
grep -q 'messages_client_message_unique_idx' "$ROOT/rust/career_ai_rust_v3/migrations/0004_global_message_idempotency.sql"
grep -q 'await widget.onSignedIn' "$ROOT/flutter/lib/features/auth/auth_screen.dart"
echo 'V20_STATIC_REGRESSION_PASS'
