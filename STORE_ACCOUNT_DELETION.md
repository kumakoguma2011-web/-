# Google Play アカウント削除対応

Google PlayのUser Data policyでは、アカウントを作成できるアプリは、アプリ内の削除導線と、アプリ外からアクセスできるWebの削除リソースの両方を提供する必要があります。

## 実装
- Web削除ページ: `/account-deletion`
- ログイン → 本人確認 → 明示的な確認 → DELETE `/account/data`
- アプリ内の削除導線: Privacy画面から同じ削除APIへ接続する
- Webページはアプリ名「ミチシルベ」を明示する
- アプリ再ダウンロードなしで削除を開始できる

## 削除対象
- users
- profiles
- anon_rules
- conversations
- messages

DBにはON DELETE CASCADEも設定しているため、関連レコードが残らないことを統合テストで確認する。

## 公開前
- 本番ドメインのHTTPS URLをPlay Consoleのアカウント削除用Web resource欄に登録
- プライバシーポリシーに削除対象・必要な保持データを正確に記載
- 実DBで削除後のバックアップ・ログ・分析基盤に残るデータの扱いを確認
