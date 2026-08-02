import '../domain/gps_sample.dart';
import '../domain/location_uploader.dart';

/// Test mock recording uploads and scripted outcomes.
class InMemoryLocationUploader implements LocationUploader {
  InMemoryLocationUploader({Iterable<LocationUploadOutcome>? outcomes})
      : _outcomes = List<LocationUploadOutcome>.from(
          outcomes ?? const <LocationUploadOutcome>[],
        );

  final List<LocationUploadOutcome> _outcomes;
  final List<LocationUploadCall> calls = [];

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
