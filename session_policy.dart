/// Local inactivity timeout for the active signed-in session.
const sessionIdleTimeout = Duration(minutes: 15);

/// Persist activity periodically without writing secure storage on every tap.
const sessionActivityPersistenceInterval = Duration(seconds: 30);

bool hasSessionExpiredFromInactivity(DateTime lastActivityAt, DateTime now) {
  final last = lastActivityAt.toUtc();
  final current = now.toUtc();
  // A future timestamp is invalid (for example, from a clock change) and
  // should not accidentally keep a session alive indefinitely.
  if (last.isAfter(current)) return true;
  return current.difference(last) >= sessionIdleTimeout;
}

Duration remainingSessionIdleTime(DateTime lastActivityAt, DateTime now) {
  if (hasSessionExpiredFromInactivity(lastActivityAt, now)) {
    return Duration.zero;
  }
  return sessionIdleTimeout - now.toUtc().difference(lastActivityAt.toUtc());
}
