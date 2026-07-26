/// One tier: while accumulated foreground poll time is below [until],
/// probe every [interval].
class KycPollTier {
  const KycPollTier({required this.until, required this.interval});

  final Duration until;
  final Duration interval;
}

/// Time-indexed, piecewise-constant poll schedule for a PENDING KYC decision.
///
/// Unlike a reconnect backoff (attempt-indexed and geometric, because each
/// attempt follows a FAILURE), this models SUCCESS polling whose *answer value*
/// decays with elapsed time: dense while an inline auto-approve blip could still
/// resolve, sparse once we are waiting on a human, then stopped.
///
/// FM-5 / D-A: the bound is accumulated FOREGROUND poll time. There is NO wall
/// clock in this class and no server-supplied value reaches it, so it has no
/// degenerate-value surface (batch rule R19) and no clock-skew surface.
class KycPollSchedule {
  const KycPollSchedule({
    required this.tiers,
    required this.tailInterval,
    required this.maxElapsed,
    required this.maxScheduledProbes,
    required this.maxResumeProbes,
  });

  static const KycPollSchedule standard = KycPollSchedule(
    tiers: [
      KycPollTier(until: Duration(seconds: 30), interval: Duration(seconds: 3)),
      KycPollTier(until: Duration(minutes: 5), interval: Duration(seconds: 15)),
    ],
    tailInterval: Duration(minutes: 1),
    maxElapsed: Duration(minutes: 15),
    maxScheduledProbes: 45, // Tripwire; natural count is 38 (T-P6).
    maxResumeProbes: 8,
  );

  final List<KycPollTier> tiers;
  final Duration tailInterval;
  final Duration maxElapsed;
  final int maxScheduledProbes;
  final int maxResumeProbes;

  /// Wait before the next automatic probe, or `null` once the schedule has
  /// expired (elapsed budget spent, or the probe tripwire hit).
  Duration? intervalAt({
    required Duration elapsed,
    required int scheduledProbes,
  }) {
    if (scheduledProbes >= maxScheduledProbes) return null;
    if (elapsed >= maxElapsed) return null;
    for (final tier in tiers) {
      if (elapsed < tier.until) return tier.interval;
    }
    return tailInterval;
  }
}
