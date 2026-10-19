# 統合テスト実行手順 v6

前提：Docker Desktop または Docker Engine + Compose が利用できるPC。

1. `cd career_ai_full_v3`
2. `docker compose -f docker-compose.integration.yml up -d --build`
3. `tests/integration_smoke.sh`
4. `docker compose -f docker-compose.integration.yml down -v`

このテストは外部Gemini APIを呼ばず、ローカルのモックGeminiを利用します。

検証項目：
- ユーザー登録
- ユーザーA/Bのデータ分離
- ZERO-CONTEXT時にプロフィールを送らない
- 通常モードでは仮名化済みプロフィールのみ送る
- 他ユーザーの会話IDを再利用できない
- 模擬面接でプロフィールを利用しない
- アカウント削除後にJWTが使えない
- Alice削除後もBobが利用可能
