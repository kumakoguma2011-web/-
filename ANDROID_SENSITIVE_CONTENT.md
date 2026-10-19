# Android sensitive-screen protection

The Flutter app now wraps the whole app tree with Flutter's `SensitiveContent` using `ContentSensitivity.sensitive`.

Flutter documents this as obscuring sensitive content during media projection on Android API 35+; on lower Android versions and other platforms it has no effect. 

This is defense-in-depth only. Do not treat it as a substitute for secure storage, authentication, authorization, HTTPS, or data minimization.

Official reference: https://docs.flutter.dev/platform-integration/android/sensitive-content
