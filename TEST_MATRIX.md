# ミチシルベ テストマトリクス v7

| 領域 | テスト | 方式 | 合格条件 |
|---|---|---|---|
| Rust | ユーザーA/B分離 | integration | 他人のprofile/chat/ruleへアクセス不可 |
| Rust | ZERO-CONTEXT | integration + mock Gemini | profileをGeminiへ送らない |
| Rust | 仮名化 | integration + mock Gemini | 生の秘密文字列がGeminiへ届かない |
| Rust | JWT失効 | integration | delete後のJWTは401 |
| Flutter | 登録 | integration_test | HomeShellへ遷移 |
| Flutter | プロフィール | integration_test | 保存成功表示 |
| Flutter | ZERO-CONTEXT | integration_test | Switch操作後も状態保持 |
| Flutter | 仮名化 | integration_test | ruleが一覧に表示 |
| Flutter | AI相談 | integration_test | mock Gemini応答を表示 |
| Flutter | API client | unit | Authorization付与・401処理 |
