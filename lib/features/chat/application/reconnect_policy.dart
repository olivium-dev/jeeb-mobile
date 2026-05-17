import 'dart:math' as math;

/// Exponential backoff schedule for the chat WebSocket reconnect loop.
///
/// `delay(0)` is fired immediately after the first failure (no wait).
/// Subsequent attempts double the previous delay up to [maxDelay]. The
/// numbers and ceiling are deliberately conservative: the chat socket is
/// expensive to spin up server-side and a tight reconnect loop is a known
/// thundering-herd risk on mobile carrier outages.
class ReconnectPolicy {
  const ReconnectPolicy({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.maxAttempts = 0,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;

  /// 0 means "retry forever". Used in tests to assert give-up paths.
  final int maxAttempts;

  /// Compute the wait before the [attempt]-th reconnect. `attempt = 1`
  /// returns [initialDelay]; later attempts grow by [multiplier] and cap at
  /// [maxDelay].
  Duration delayFor(int attempt) {
    if (attempt <= 0) return Duration.zero;
    final base = initialDelay.inMilliseconds.toDouble();
    final scaled = base * math.pow(multiplier, attempt - 1);
    final capped = math.min(scaled, maxDelay.inMilliseconds.toDouble());
    return Duration(milliseconds: capped.round());
  }

  bool shouldGiveUp(int attempt) =>
      maxAttempts > 0 && attempt >= maxAttempts;
}
