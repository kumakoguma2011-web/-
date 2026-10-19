# アカウント削除 Web フロー

## URL
`https://<本番APIドメイン>/account-deletion`

## フロー
1. 登録メールアドレス＋パスワードで本人確認
2. 削除対象を説明
3. 明示的な確認チェック
4. `DELETE /account/data`
5. users / profiles / anon_rules / conversations / messages を削除
6. 完了画面を表示

## セキュリティ
- アクセストークンはページのJavaScriptメモリ上だけで保持
- URLクエリにトークンやパスワードを入れない
- 同一オリジンのWebページとして配信しCORS依存を避ける
- 本番はHTTPS
- 削除後はDB上のユーザー存在チェックにより旧JWTを無効化

## Google Play対応
Google Playの現行User Data policyでは、アカウント作成をサポートするアプリは、アプリ内とアプリ外Webの両方からアカウント削除を開始できる必要がある。Play ConsoleにはこのWebリソースURLを登録する。
