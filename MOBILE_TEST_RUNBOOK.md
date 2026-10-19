# ミチシルベ モバイル実機・エミュレータテスト手順 v7

Flutter公式の `integration_test` を使用する。公式ドキュメントでは、Android実機・iOS実機・エミュレータ等で統合テストを実行できる。現行ドキュメントはFlutter 3.44.7を対象としている。 citeturn249982search0turn249982search4

## 1. バックエンド

```bash
docker compose -f docker-compose.integration.yml up -d --build
```

外部Geminiではなく `tests/mock_gemini.py` を利用する。

## 2. Flutter依存関係

```bash
cd flutter
flutter pub get
```

## 3. Android Emulator

Android EmulatorからPC上のAPIへ接続する場合は通常 `10.0.2.2` を使う。

```bash
flutter devices
flutter test integration_test/app_smoke_test.dart \
  -d <device-id> \
  --dart-define=CAREER_AI_API_BASE_URL=http://10.0.2.2:8080
```

## 4. Android実機

PCと端末が同じLAN上にある場合、API_BASE_URLにPCのLAN IPを指定する。

```bash
flutter devices
flutter test integration_test/app_smoke_test.dart \
  -d <device-id> \
  --dart-define=CAREER_AI_API_BASE_URL=http://<PCのLAN-IP>:8080
```

本番相当の検証ではHTTPS終端を用いる。

## 5. iOS Simulator / 実機

macOS + Xcodeが必要。Flutter公式のintegration_test手順に従う。 citeturn249982search0turn249982search7

## 6. 自動テストの内容

1. 新規アカウント登録
2. HomeShellへの遷移
3. プロフィール保存
4. ZERO-CONTEXT ON
5. 仮名化ルール追加
6. 相談画面への遷移
7. チャット送信
8. AI応答表示

## 7. 完了条件

Flutter側の `integration_test` が `All tests passed!` になること。バックエンド側の `tests/integration_smoke.sh` もPASSすること。両方通った時点を「開発版の通し動作確認完了」とする。
