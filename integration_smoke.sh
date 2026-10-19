#!/usr/bin/env bash
set -euo pipefail
BASE="${BASE_URL:-http://127.0.0.1:58081}"

echo '[1/13] health'
curl -fsS "$BASE/health" | grep -q '"ok":true'

echo '[2/13] register Alice'
A=$(curl -fsS -X POST "$BASE/auth/register" -H 'Content-Type: application/json' -d '{"email":"alice@example.test","password":"alice-password-123"}')
AT=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$A")

echo '[3/13] register Bob'
B=$(curl -fsS -X POST "$BASE/auth/register" -H 'Content-Type: application/json' -d '{"email":"bob@example.test","password":"bob-password-123"}')
BT=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$B")

echo '[4/13] Alice profile + rule'
curl -fsS -X PUT "$BASE/profile" -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' \
  -d '{"free_text":"AliceSecret","status":"学生","gender":"未回答・回答しない","location":"愛知県","personality":"慎重","relationships":"少人数が得意","hobbies":"読書","priority":"成長"}' >/dev/null
curl -fsS -X POST "$BASE/anon-rules" -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' \
  -d '{"original":"AliceSecret","label":"[相談者A]"}' >/dev/null

echo '[5/13] Bob cannot use Alice rule id (expects 404)'
RULE_ID=$(curl -fsS "$BASE/anon-rules" -H "Authorization: Bearer $AT" | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')
STATUS=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/anon-rules/$RULE_ID" -H "Authorization: Bearer $BT")
test "$STATUS" = 404

echo '[6a] new conversation endpoint returns a fresh conversation'
NEWC=$(curl -fsS -X POST "$BASE/conversations" -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' -d '{}')
NEWCID=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["conversation_id"])' <<<"$NEWC")
TESTMSG=$(curl -fsS "$BASE/conversations/$NEWCID/messages" -H "Authorization: Bearer $AT")
test "$TESTMSG" = '[]'

echo '[6/13] ZERO-CONTEXT chat must not leak Alice profile'
CHAT=$(curl -fsS -X POST "$BASE/chat" -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' \
  -d '{"client_message_id":"11111111-1111-4111-8111-111111111111","message":"AliceSecretについて相談したい","zero_context":true,"step":1}')
echo "$CHAT" | grep -q 'MOCK_ZERO_CONTEXT_OK'

echo '[7/13] non-ZERO chat passes the anonymized profile contract'
CHAT2=$(curl -fsS -X POST "$BASE/chat" -H "Authorization: Bearer $AT" -H 'Content-Type: application/json' \
  -d '{"client_message_id":"22222222-2222-4222-8222-222222222222","message":"AliceSecretについて相談したい","zero_context":false,"step":1}')
echo "$CHAT2" | grep -q 'MOCK_PROFILE_SANITIZED_OK'

echo '[8/13] Bob cannot use Alice conversation id'
CID=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["conversation_id"])' <<<"$CHAT2")
STATUS_CONV=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/chat" -H "Authorization: Bearer $BT" -H 'Content-Type: application/json' -d "{\"conversation_id\":\"$CID\",\"message\":\"他人の会話にアクセスできないか\",\"zero_context\":true,\"step\":1}")
test "$STATUS_CONV" = 401

echo '[8a] deleting a conversation removes its cached AI response'
STATUS_DEL_CONV=$(curl -s -o /dev/null -w '%{http_code}' -X DELETE "$BASE/conversations/$CID" -H "Authorization: Bearer $AT")
test "$STATUS_DEL_CONV" = 204
RESIDUAL_REQUEST=$(docker compose exec -T postgres psql -U career_ai -d career_ai -At -c "SELECT count(*) FROM chat_requests WHERE client_message_id='22222222-2222-4222-8222-222222222222';" | tr -d '\r' | tail -n 1)
test "$RESIDUAL_REQUEST" = '0'

echo '[9/13] interview does not use profile'
INTERVIEW=$(curl -fsS -X POST "$BASE/interview" -H "Authorization: Bearer $BT" -H 'Content-Type: application/json' -d '{"answer":"期限が厳しい仕事で、作業を分解して優先順位をつけ、期限内に終えました"}')
echo "$INTERVIEW" | grep -q 'MOCK_INTERVIEW_OK'

echo '[10/13] account deletion'
ALICE_ID=$(docker compose exec -T postgres psql -U career_ai -d career_ai -At -c "SELECT id FROM users WHERE email='alice@example.test';" | tr -d '\r' | tail -n 1)
curl -fsS -X DELETE "$BASE/account/data" -H "Authorization: Bearer $AT" >/dev/null
STATUS2=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/profile" -H "Authorization: Bearer $AT")
test "$STATUS2" = 401

echo '[11/13] verify deleted-account data is physically absent from PostgreSQL'
POSTGRES_SERVICE="postgres"
# The integration database is disposable; direct SQL verification is intentional here.
COUNTS=$(docker compose exec -T "$POSTGRES_SERVICE" psql -U career_ai -d career_ai -At -F '|' -c "SELECT
  (SELECT count(*) FROM users WHERE email='alice@example.test') AS users,
  (SELECT count(*) FROM profiles p JOIN users u ON u.id=p.user_id WHERE u.email='alice@example.test') AS profiles,
  (SELECT count(*) FROM anon_rules a JOIN users u ON u.id=a.user_id WHERE u.email='alice@example.test') AS anon_rules,
  (SELECT count(*) FROM conversations c JOIN users u ON u.id=c.user_id WHERE u.email='alice@example.test') AS conversations,
  (SELECT count(*) FROM messages m JOIN conversations c ON c.id=m.conversation_id JOIN users u ON u.id=c.user_id WHERE u.email='alice@example.test') AS messages;" | tr -d '\r' | tail -n 1)
CHAT_REQUESTS=$(docker compose exec -T postgres psql -U career_ai -d career_ai -At -c "SELECT count(*) FROM chat_requests WHERE user_id='$ALICE_ID';" | tr -d '\r' | tail -n 1)
test "$COUNTS" = '0|0|0|0|0'
test "$CHAT_REQUESTS" = '0'

# Bob's account is still alive.
curl -fsS "$BASE/profile" -H "Authorization: Bearer $BT" >/dev/null
# Bob remains able to create his own rule and chat after Alice deletion.
curl -fsS -X POST "$BASE/anon-rules" -H "Authorization: Bearer $BT" -H 'Content-Type: application/json' -d '{"original":"BobSecret","label":"[相談者B]"}' >/dev/null
curl -fsS -X POST "$BASE/chat" -H "Authorization: Bearer $BT" -H 'Content-Type: application/json' -d '{"message":"BobSecretの相談","zero_context":true,"step":1}' >/dev/null

echo '[12/13] verify no orphaned child rows remain'
ORPHANS=$(docker compose exec -T "$POSTGRES_SERVICE" psql -U career_ai -d career_ai -At -F '|' -c "SELECT (SELECT count(*) FROM profiles p LEFT JOIN users u ON u.id=p.user_id WHERE u.id IS NULL) || '|' || (SELECT count(*) FROM anon_rules a LEFT JOIN users u ON u.id=a.user_id WHERE u.id IS NULL) || '|' || (SELECT count(*) FROM conversations c LEFT JOIN users u ON u.id=c.user_id WHERE u.id IS NULL) || '|' || (SELECT count(*) FROM messages m LEFT JOIN conversations c ON c.id=m.conversation_id WHERE c.id IS NULL);" | tr -d '\r' | tail -n 1)
test "$ORPHANS" = '0|0|0|0'

echo '[13/13] verify Bob remains in PostgreSQL'
BOB_COUNT=$(docker compose exec -T "$POSTGRES_SERVICE" psql -U career_ai -d career_ai -At -c "SELECT count(*) FROM users WHERE email='bob@example.test';" | tr -d '\r' | tail -n 1)
test "$BOB_COUNT" = '1'

echo 'INTEGRATION SMOKE: PASS'
