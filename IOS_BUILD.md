# iOS リリース手順

```bash
cd flutter
flutter pub get
flutter analyze
flutter test
flutter build ios --release \
  --dart-define=CAREER_AI_API_BASE_URL=https://api.example.com
```

その後 Xcode で Release configuration / Signing / Bundle Identifier を確認し、Archive → Distribute App へ進みます。

重要：Debug 用のローカルネットワーク設定は Release へ持ち込まないでください。
Privacy Manifest (`PrivacyInfo.xcprivacy`) と App Store Connect の App Privacy は、実際の収集・利用内容に合わせて記載します。
