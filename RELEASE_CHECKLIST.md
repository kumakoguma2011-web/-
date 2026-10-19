# ミチシルベ リリース前チェックリスト

このチェックリストは、現在の Flutter + Rust/Axum + PostgreSQL + Gemini 構成を Android / iOS の本番アプリとして公開する前に確認するためのものです。

## 共通
- [ ] `CAREER_AI_API_BASE_URL` は本番 HTTPS URL
- [ ] Gemini API キーは Flutter アプリに存在しない
- [ ] 本番 Secret は `.env` や Git に保存しない
- [ ] Rust API は HTTPS 経由のみで公開
- [ ] PostgreSQL はインターネットへ直接公開しない
- [ ] ログにパスワード、JWT、プロフィール、チャット本文を出さない
- [ ] アカウント削除でサーバー側データも削除される
- [ ] ZERO-CONTEXT の実機テストに合格
- [ ] ユーザーA→ユーザーBのデータアクセス拒否テストに合格
- [ ] 依存関係の脆弱性監査を実施
- [ ] Privacy Policy をアプリ内と公開URLの両方で確認

## Android
- [ ] Android Studio / Android SDK のリリース環境を準備
- [ ] アプリ署名キーを安全な場所に保管
- [ ] `applicationId` を本番IDに固定
- [ ] versionCode / versionName を設定
- [ ] Release build でデバッグ機能が無効
- [ ] `flutter build appbundle` 成功
- [ ] 実機でログイン・相談・削除を確認
- [ ] Play Console の Data safety を実装実態と一致させる
- [ ] 必要な権限だけを要求

## iOS
- [ ] Bundle Identifier を本番IDに固定
- [ ] Signing / Team / Provisioning を確認
- [ ] Release 版で Debug 用 Local Network 設定を有効にしない
- [ ] `PrivacyInfo.xcprivacy` を実装内容に合わせて確定
- [ ] App Store Connect の App Privacy を実装実態と一致させる
- [ ] 実機でログイン・相談・削除を確認
- [ ] Review 用テストアカウント等を準備

## ストア公開前
- [ ] プライバシーポリシー公開
- [ ] 利用規約公開
- [ ] アカウント削除方法をアプリ内から確認可能
- [ ] 第三者SDK一覧を確定
- [ ] AIへのデータ送信先と利用目的を明記
- [ ] マイク等の権限利用目的を明記
