/// Battery + accuracy tuning knobs for the background GPS pipeline.
///
/// Defaults mirror the JEEB-73 acceptance criteria: 10s active cadence,
/// 60s when stationary, 50m accuracy ceiling, 0.5 m/s (≈1.8 km/h)
/// stationary threshold. Tests construct their own config to compress
/// these intervals into milliseconds.
class BackgroundGpsConfig {
  const BackgroundGpsConfig({
    this.activeInterval = const Duration(seconds: 10),
    this.stationaryInterval = const Duration(seconds: 60),
    this.maxAccuracyMeters = 50.0,
    this.stationaryThresholdMps = 0.5,
    this.maxConsecutiveUploadFailures = 5,
    this.uploadRetryBackoff = const Duration(seconds: 5),
  });

  /// Minimum gap between two uploaded samples while the Jeeber is moving.
  /// Samples that arrive sooner are dropped silently — the plugin keeps
  /// the OS GPS chip warm, but we conserve bandwidth + battery by not
  /// hammering the gateway.
  final Duration activeInterval;

  /// Minimum gap once the Jeeber is detected stationary (speed below
  /// [stationaryThresholdMps]). Bumping this 6×-ish is the biggest
  /// battery lever — a parked scooter doesn't need second-by-second pings.
  final Duration stationaryInterval;

  /// Samples with `accuracyMeters` above this are discarded entirely —
  /// they're typically tower-only fixes that would draw the map to the
  /// wrong street. The backend never sees these.
  final double maxAccuracyMeters;

  /// Speed below this value classifies the Jeeber as stationary and
  /// switches the cadence to [stationaryInterval]. Chosen well above
  /// the GPS jitter floor (≈0.2 m/s) so a parked rider doesn't flap.
  final double stationaryThresholdMps;

  /// Stops the upload loop after this many consecutive transient failures
  /// — the cubit emits [BackgroundGpsPhase.error] so the screen can show
  /// the offline banner. Reset to zero on the first success.
  final int maxConsecutiveUploadFailures;

  /// Cooldown before retrying after a transient failure. Capped, no
  /// exponential growth — the cadence already throttles us hard enough.
  final Duration uploadRetryBackoff;
}
