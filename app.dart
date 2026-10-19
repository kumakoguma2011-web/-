import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_store.dart';
import '../services/local_vault.dart';
import '../features/auth/auth_screen.dart';
import 'home_shell.dart';
import 'privacy_guard.dart';
import 'session_policy.dart';
import 'theme.dart';

class CareerAiApp extends StatefulWidget {
  const CareerAiApp({super.key, required this.api, required this.authStore, required this.vault});
  final ApiClient api;
  final AuthStore authStore;
  final LocalVault vault;

  @override
  State<CareerAiApp> createState() => _CareerAiAppState();
}

class _CareerAiAppState extends State<CareerAiApp> with WidgetsBindingObserver {
  bool? signedIn;
  Timer? inactivity;
  DateTime? _lastActivityAt;
  DateTime? _lastPersistedActivityAt;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    try {
      final token = await widget.authStore.readToken();
      if (!mounted) return;
      if (token == null) {
        setState(() => signedIn = false);
        return;
      }

      final rawActivity = await widget.authStore.readLastActivity();
      final lastActivity = rawActivity == null ? null : DateTime.tryParse(rawActivity);
      final now = DateTime.now().toUtc();
      if (lastActivity == null || hasSessionExpiredFromInactivity(lastActivity, now)) {
        await widget.authStore.clearAll();
        await widget.vault.clearAll();
        if (mounted) setState(() => signedIn = false);
        return;
      }

      final userKey = await widget.authStore.readUserKey();
      if (userKey == null || userKey.trim().isEmpty) {
        await widget.authStore.clearAll();
        await widget.vault.clearAll();
        if (mounted) setState(() => signedIn = false);
        return;
      }

      _lastActivityAt = lastActivity.toUtc();
      _lastPersistedActivityAt = _lastActivityAt;
      widget.vault.setUserScope(userKey);
      widget.api.accessToken = token;
      widget.api.onUnauthorized = _sessionExpired;
      await widget.api.get('/profile');
      if (mounted) {
        setState(() {
          _restoreError = null;
          signedIn = true;
        });
        _armTimeout();
      }
    } catch (_) {
      // A temporary network/server error must not erase a valid local session.
      // A 401 is handled by ApiClient.onUnauthorized and changes signedIn.
      if (mounted && signedIn == null) {
        setState(() => _restoreError =
            'サーバーへの接続、または保存データの確認に失敗しました。通信状態を確認して、もう一度お試しください。');
      }
    }
  }

  Future<void> _retryRestore() async {
    if (!mounted) return;
    setState(() => _restoreError = null);
    await _restore();
  }

  Future<void> _onSignedIn(String token, String userKey) async {
    widget.api.onUnauthorized = _sessionExpired;
    widget.vault.setUserScope(userKey);
    widget.api.accessToken = token;
    await widget.authStore.save(token: token, userKey: userKey);
    final now = DateTime.now().toUtc();
    _lastActivityAt = now;
    _lastPersistedActivityAt = now;
    await widget.authStore.saveLastActivity(now);
    if (!mounted) return;
    setState(() => signedIn = true);
    _armTimeout();
  }

  Future<void> _sessionExpired() async {
    inactivity?.cancel();
    _lastActivityAt = null;
    _lastPersistedActivityAt = null;
    widget.api.onUnauthorized = null;
    widget.api.accessToken = null;
    await widget.authStore.clearAll();
    await widget.vault.clearAll();
    if (mounted) setState(() => signedIn = false);
  }

  Future<void> _logout() async {
    inactivity?.cancel();
    _lastActivityAt = null;
    _lastPersistedActivityAt = null;
    widget.api.onUnauthorized = null;
    widget.api.accessToken = null;
    await widget.authStore.clearAll();
    await widget.vault.clearAll();
    if (mounted) setState(() => signedIn = false);
  }

  void _armTimeout() {
    inactivity?.cancel();
    if (signedIn != true) return;
    final last = _lastActivityAt ?? DateTime.now().toUtc();
    final remaining = remainingSessionIdleTime(last, DateTime.now().toUtc());
    if (remaining.inMilliseconds <= 0) {
      unawaited(_logout());
      return;
    }
    inactivity = Timer(remaining, () => unawaited(_logout()));
  }

  Future<void> _persistActivity(DateTime at) async {
    try {
      await widget.authStore.saveLastActivity(at);
    } catch (_) {
      // The in-memory timeout remains active even if secure storage is unavailable.
    }
  }

  void _activity() {
    if (signedIn != true) return;
    final now = DateTime.now().toUtc();
    _lastActivityAt = now;
    _armTimeout();
    final lastPersisted = _lastPersistedActivityAt;
    if (lastPersisted == null ||
        now.difference(lastPersisted) >= sessionActivityPersistenceInterval) {
      _lastPersistedActivityAt = now;
      unawaited(_persistActivity(now));
    }
  }

  Future<void> _checkIdleOnResume() async {
    if (signedIn != true) return;
    final lastActivity = _lastActivityAt;
    if (lastActivity == null ||
        hasSessionExpiredFromInactivity(lastActivity, DateTime.now().toUtc())) {
      await _logout();
      return;
    }
    _armTimeout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (signedIn != true) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final lastActivity = _lastActivityAt;
      if (lastActivity != null) {
        _lastPersistedActivityAt = lastActivity;
        unawaited(_persistActivity(lastActivity));
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_checkIdleOnResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.api.baseUrl.trim().isEmpty) {
      return MaterialApp(
        theme: MichishirubeTheme.light(),
        home: const Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 52),
                    SizedBox(height: 16),
                    Text('サーバー設定が必要です', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('CAREER_AI_API_BASE_URL を設定してからアプリを起動してください。', textAlign: TextAlign.center),
                    SizedBox(height: 8),
                    Text('開発時は --dart-define=CAREER_AI_API_BASE_URL=https://... を指定します。', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final content = PrivacyGuard(
      child: signedIn == null
          ? _restoreError == null
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                '接続を確認してください',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Text(_restoreError!, textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _retryRestore,
                                icon: const Icon(Icons.refresh),
                                label: const Text('再試行'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
          : signedIn!
              ? HomeShell(api: widget.api, vault: widget.vault, onLogout: _logout, onActivity: _activity)
              : AuthScreen(api: widget.api, onSignedIn: _onSignedIn),
    );
    return MaterialApp(
      theme: MichishirubeTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Listener(onPointerDown: (_) => _activity(), child: content),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    inactivity?.cancel();
    super.dispose();
  }
}
