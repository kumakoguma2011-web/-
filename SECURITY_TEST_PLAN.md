# ミチシルベ セキュリティテスト計画

## 1. 認可境界
- User A のJWTで User B のconversation_idを指定 → 401/403相当で拒否
- User A のJWTで User B のanon-rule idを削除 → 404/拒否
- User A のJWTで User B のprofileを取得 → User A のprofileだけ返る

## 2. ZERO-CONTEXT
- true のとき profile SELECT を実行しない
- Gemini送信payloadにプロフィールJSONが存在しない
- 会話DBにプロフィールスナップショットを保存しない

## 3. 仮名化
- 電話、メール、郵便番号、日付をGemini送信前に置換
- ユーザー固有ルールは必ず認証ユーザーのDBからロード
- 仮名化前のユーザーメッセージをサーバーログへ出さない

## 4. 認証
- 12文字未満のパスワード拒否
- Argon2ハッシュのみDB保存
- JWT期限切れを拒否
- Bearer形式以外を拒否

## 5. 本番前に追加
- refresh token rotation
- email verification / password reset
- IP + user rate limit
- Gemini予算上限
- HTTPS終端
- 厳格なCORS許可リスト
- secret manager
- 監査ログからPII除外
- account deletion + cascade確認
- DBバックアップ/保持期間の確認
- cargo audit / cargo deny / secret scan
