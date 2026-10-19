import 'package:flutter/material.dart';

/// Adds two layers of screen privacy protection:
/// 1) Flutter's SensitiveContent on Android API 35+ to obscure media projection.
/// 2) A full-screen privacy veil whenever the app becomes inactive/paused,
///    reducing exposure in the app switcher and during transient backgrounding.
class PrivacyGuard extends StatefulWidget {
  const PrivacyGuard({super.key, required this.child});
  final Widget child;

  @override
  State<PrivacyGuard> createState() => _PrivacyGuardState();
}

class _PrivacyGuardState extends State<PrivacyGuard> with WidgetsBindingObserver {
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final shouldObscure = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
    if (mounted && shouldObscure != _obscured) {
      setState(() => _obscured = shouldObscure);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SensitiveContent(
          sensitivity: ContentSensitivity.sensitive,
          child: widget.child,
        ),
        if (_obscured)
          const ColoredBox(
            color: Color(0xFF0F172A),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                color: Color(0xFF94A3B8),
                size: 42,
              ),
            ),
          ),
      ],
    );
  }
}
