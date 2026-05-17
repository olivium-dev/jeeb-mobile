import 'package:equatable/equatable.dart';

/// A single GPS fix as it comes out of [GeocaptureGateway].
///
/// The accuracy filter ([BackgroundGpsConfig.maxAccuracyMeters]) and the
/// stationary detector ([BackgroundGpsConfig.stationaryThresholdMps]) both
/// read off this. The cubit never mutates samples — discard or forward.
class GpsSample extends Equatable {
  const GpsSample({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedMps,
    required this.headingDegrees,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;

  /// Horizontal accuracy reported by the OS in metres. The lower the better.
  /// Samples above [BackgroundGpsConfig.maxAccuracyMeters] are discarded.
  final double accuracyMeters;

  /// Ground speed in metres-per-second. Drives the battery throttle —
  /// values below [BackgroundGpsConfig.stationaryThresholdMps] mean the
  /// Jeeber is parked and we can back off to [stationaryInterval].
  final double speedMps;

  /// Compass bearing, 0..360, never null. The OS hands `nan` back when it
  /// can't compute one — gateway impls coerce that to `0` before emitting.
  final double headingDegrees;

  /// When the OS captured this fix, not when we received it. Used as the
  /// `recorded_at` payload field so backend can detect stale buffers.
  final DateTime capturedAt;

  @override
  List<Object?> get props => [
        latitude,
        longitude,
        accuracyMeters,
        speedMps,
        headingDegrees,
        capturedAt,
      ];
}
