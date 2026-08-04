class AvailabilityInactivityPolicy {
  const AvailabilityInactivityPolicy({
    this.autoOfflineAfter = const Duration(hours: 8),
    this.warnAfter = const Duration(hours: 7, minutes: 30),
  });

  final Duration autoOfflineAfter;
  final Duration warnAfter;

  bool shouldWarn(Duration elapsed) =>
      elapsed >= warnAfter && elapsed < autoOfflineAfter;

  bool shouldAutoOffline(Duration elapsed) => elapsed >= autoOfflineAfter;
}
