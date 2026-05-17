import '../domain/gps_sample.dart';
import '../domain/location_uploader.dart';

/// Records every upload so tests can assert call cadence without faking
/// the cubit. The scripted [outcomes] queue lets a test rehearse a
/// failure → success sequence and verify the failure counter resets.
class InMemoryLocationUploader implements LocationUploader {
  InMemoryLocationUploader({Iterable<LocationUploadOutcome>? outcomes})
      : _outcomes = List<LocationUploadOutcome>.from(
          outcomes ?? const <LocationUploadOutcome>[],
        );

  final List<LocationUploadOutcome> _outcomes;
  final List<LocationUploadCall> calls = [];

  /// Default returned once the scripted [_outcomes] queue is drained.
  LocationUploadOutcome defaultOutcome = LocationUploadOutcome.accepted;

  @override
  Future<LocationUploadOutcome> upload({
    required String deliveryId,
    required GpsSample sample,
  }) async {
    calls.add(LocationUploadCall(deliveryId: deliveryId, sample: sample));
    if (_outcomes.isEmpty) return defaultOutcome;
    return _outcomes.removeAt(0);
  }
}

class LocationUploadCall {
  const LocationUploadCall({required this.deliveryId, required this.sample});
  final String deliveryId;
  final GpsSample sample;
}
