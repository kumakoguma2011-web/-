import 'package:flutter_test/flutter_test.dart';
import '../lib/core/session_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);

  test('session stays active just before the inactivity limit', () {
    final lastActivity = now.subtract(const Duration(minutes: 14, seconds: 59));
    expect(hasSessionExpiredFromInactivity(lastActivity, now), isFalse);
    expect(remainingSessionIdleTime(lastActivity, now), const Duration(seconds: 1));
  });

  test('session expires at the inactivity limit', () {
    final lastActivity = now.subtract(const Duration(minutes: 15));
    expect(hasSessionExpiredFromInactivity(lastActivity, now), isTrue);
    expect(remainingSessionIdleTime(lastActivity, now), Duration.zero);
  });

  test('a future activity timestamp is rejected', () {
    expect(
      hasSessionExpiredFromInactivity(now.add(const Duration(seconds: 1)), now),
      isTrue,
    );
  });
}
