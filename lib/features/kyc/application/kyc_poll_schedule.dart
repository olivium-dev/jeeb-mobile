class KycPollTier {
  const KycPollTier({required this.until, required this.interval});

  final Duration until;
  final Duration interval;
}

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
