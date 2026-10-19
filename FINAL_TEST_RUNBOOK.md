# ミチシルベ 最終検証ランブック

## 目的
この文書は、開発PC上で「バックエンド統合」「Flutter」「Release準備」を一つの順序で検証するための最終手順です。

## 0. 前提
- Rust stable / cargo
- Flutter SDK（公式の現行ドキュメントに合わせて、Flutter 3.44 系以降を推奨）
- Docker Desktop または同等のDocker環境
- Android Studio（Android実機/エミュレータ用）
- iOS実機テストにはmacOS + Xcodeが必要

## 1. 静的チェック
```bash
./scripts/final_verification.sh
```

このスクリプトは、利用できるツールがない環境では「SKIP」と明示して止まりません。

## 2. Rust + PostgreSQL + Mock Gemini
```bash
docker compose -f docker-compose.integration.yml up -d --build
tests/integration_smoke.sh
docker compose -f docker-compose.integration.yml down -v
```

PASS条件：`INTEGRATION SMOKE: PASS`

検査内容：
- ユーザーA/Bの登録
- ユーザーごとのデータ分離
- 仮名化
- ZERO-CONTEXT
- 会話所有権
- STAR面接でプロフィールを利用しないこと
- アカウント削除
- 削除後JWT無効化
- PostgreSQLの残存データ0件
- 孤立レコード0件
- 別ユーザーが継続利用可能

## 3. Flutter単体テスト
```bash
cd flutter
flutter pub get
flutter analyze
flutter test
```

## 4. Android統合テスト
1. Android Emulatorまたは実機を起動
2. Backend統合環境を起動
3. `10.0.2.2` はAndroid EmulatorからホストPCを指す場合の既定値
4. 実行：
```bash
cd ..
CAREER_AI_API_BASE_URL=http://10.0.2.2:8080 scripts/run_flutter_android_integration.sh
```

## 5. iOS統合テスト
- macOS + XcodeでiOS Simulator/実機を起動
- HTTPSの検証用API URLを `CAREER_AI_API_BASE_URL` に設定
- `flutter test integration_test/app_smoke_test.dart -d <device-id> --dart-define=CAREER_AI_API_BASE_URL=<URL>`

## 6. Release候補
Android：
```bash
flutter build appbundle --release
```
Flutter公式ではGoogle Play向けにApp Bundleが推奨されています。

iOS：XcodeでRelease Archiveを作成し、TestFlightで確認します。

## 7. 公開直前の停止条件
次のどれか一つでも未確認なら本番公開しない：
- Gemini APIキーがアプリに入っている
- DBユーザー分離が未確認
- ZERO-CONTEXTが未確認
- アカウント削除のDB残存0確認が未実施
- Android/iOS実機でログイン・相談・削除が未確認
- Privacy申告と実装が一致していない
- HTTPSが未確認
