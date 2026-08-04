/// Battery + accuracy tuning for background GPS pipeline. Defaults from JEEB-73 AC.
class BackgroundGpsConfig {
  const BackgroundGpsConfig({
    this.activeInterval = const Duration(seconds: 10),
    this.stationaryInterval = const Duration(seconds: 60),
    this.maxAccuracyMeters = 50.0,
    this.stationaryThresholdMps = 0.5,
    this.maxConsecutiveUploadFailures = 5,
    this.uploadRetryBackoff = const Duration(seconds: 5),
  });

  /// Min gap between uploads while moving; sooner samples dropped.
  final Duration activeInterval;

  /// Min gap when stationary; major battery lever (parked doesn't need per-second pings).
  final Duration stationaryInterval;

  /// Discard samples above this accuracy (tower-only fixes draw map to wrong street).
  final double maxAccuracyMeters;

  /// Below this speed: stationary, switch to stationaryInterval. Above GPS jitter floor.
  final double stationaryThresholdMps;

  /// Max consecutive failures before emitting error phase and showing offline banner.
  final int maxConsecutiveUploadFailures;

  /// Cooldown before retry after transient failure; capped, no exponential growth.
  final Duration uploadRetryBackoff;
}
