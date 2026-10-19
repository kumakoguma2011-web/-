# ミチシルベ v28 回帰修正メモ

## 修正1: 同時二重送信
`client_message_id`ごとに`chat_requests`を予約する。既にprocessing/completedなら2回目はGeminiを呼ばず、completed結果を返すかprocessingとして待機する。

## 修正2: API接続先未設定
`https://api.example.com`をデフォルトにせず、未設定ならアプリ上で「サーバー設定が必要」と明示する。

## 修正3: サーバー状態不明時のプロフィール表示
プロフィール取得に失敗した場合、古い端末キャッシュを暗黙に表示しない。サーバー確認ができない場合はエラーを表示する。

## 追加の安全策
Gemini成功後のDB保存失敗時はprocessing予約を削除し、次回の再送が詰まらないようにする。
