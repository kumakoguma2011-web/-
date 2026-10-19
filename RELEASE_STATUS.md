# Release status

## Implemented in source
- Flutter client and Rust backend are wired to the same API paths.
- Gemini API key is server-only.
- Argon2 password hashing.
- 8-hour maximum JWT access-token lifetime, with a 15-minute inactivity timeout persisted across app restarts and background/resume transitions.
- User-scoped profile and anonymization rules.
- ZERO-CONTEXT enforced server-side.
- Anonymized chat storage.
- STAR interview endpoint.
- Full account/data deletion endpoint with DB transaction.

## Not yet verified in this environment
- `flutter pub get` / `flutter analyze` / Android build / iOS build
- `cargo check` / `cargo test`
- Live PostgreSQL migrations
- Live Gemini API call
- Device-level Keychain/Keystore behavior on physical devices

The current environment does not contain Flutter/Dart/Rust toolchains, so these final execution checks must be run on a development machine.
