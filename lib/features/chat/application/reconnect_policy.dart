import 'dart:math' as math;

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

  final int maxAttempts;

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
