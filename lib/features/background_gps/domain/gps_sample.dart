import 'package:equatable/equatable.dart';

/// GPS fix from GeocaptureGateway. Accuracy and speed drive filtering/throttling.
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

  /// Horizontal accuracy (metres). Samples above maxAccuracyMeters are discarded.
  final double accuracyMeters;

  /// Speed (m/s). Below stationaryThresholdMps: parked, switch to stationary cadence (battery).
  final double speedMps;

  /// Compass bearing 0..360. OS returns nan → gateway coerces to 0 before emitting.
  final double headingDegrees;

  /// OS capture time (not receive time); used as recorded_at to detect stale buffers.
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
