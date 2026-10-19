# Android リリース手順

Flutter公式の現行デプロイガイドでは、Google Play向けのリリースは App Bundle (`.aab`) が推奨されています。

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=CAREER_AI_API_BASE_URL=https://api.example.com
```

生成物は通常、`build/app/outputs/bundle/release/app-release.aab` です。

公開前に Play App Signing / upload key を設定し、秘密鍵をGitに入れないでください。

また、ミチシルベ は個人情報・センシティブ情報を扱うため、Play Consoleの Data safety と権限申告は実装実態と一致させます。
