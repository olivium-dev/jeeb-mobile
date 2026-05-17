/// Idle-driven auto-offline rules for the Jeeber.
///
/// A Jeeber who has been online but inactive for [autoOfflineAfter] is
/// flipped offline. [warnAfter] (always strictly less than
/// [autoOfflineAfter]) controls when the UI surfaces a "you'll be taken
/// offline soon" warning so the Jeeber can tap to extend.
///
/// Defaults match the spec on JEEB-80: warn at 7h30, auto-offline at 8h.
class AvailabilityInactivityPolicy {
  const AvailabilityInactivityPolicy({
    this.autoOfflineAfter = const Duration(hours: 8),
    this.warnAfter = const Duration(hours: 7, minutes: 30),
  });

  final Duration autoOfflineAfter;
  final Duration warnAfter;

  /// Whether [elapsed] since the last activity has crossed the warning
  /// threshold but not yet the auto-offline threshold.
  bool shouldWarn(Duration elapsed) =>
      elapsed >= warnAfter && elapsed < autoOfflineAfter;

  /// Whether [elapsed] since the last activity has crossed the
  /// auto-offline threshold.
  bool shouldAutoOffline(Duration elapsed) => elapsed >= autoOfflineAfter;
}
