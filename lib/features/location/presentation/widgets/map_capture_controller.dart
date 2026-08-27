import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/location_repository.dart';
import '../../domain/reverse_geocoder.dart';

class MapCaptureController extends ChangeNotifier {
  MapCaptureController({
    required LocationPoint initial,
    ReverseGeocoder? reverseGeocoder,
  }) : _center = initial,
       _reverseGeocoder = reverseGeocoder;

  LocationPoint _center;
  final ReverseGeocoder? _reverseGeocoder;
  bool _ready = false;
  bool _disposed = false;
  int _reverseGeocodeToken = 0;

  LocationPoint get center => _center;

  /// True once the live camera has reported at least one `onCameraIdle`.
  /// Gates the confirm CTA so a pre-idle tap can never hand back a false pin.
  bool get isReady => _ready;

  void updateCenter(LocationPoint next) {
    if (next.latitude == _center.latitude &&
        next.longitude == _center.longitude) {
      return;
    }
    _center = next;
    // Invalidate any lookup for the previous centre immediately. This only
    // advances an in-memory token; the OS lookup still starts on camera idle.
    _reverseGeocodeToken++;
    notifyListeners();
  }

  /// Marks the camera settled and starts a best-effort address lookup.
  ///
  /// Readiness is published before the fire-and-forget lookup starts. Every
  /// later idle starts a new lookup, while camera moves invalidate older ones.
  void markReady() {
    if (!_ready) {
      _ready = true;
      notifyListeners();
    }
    final geocoder = _reverseGeocoder;
    if (geocoder == null) return;
    final point = _center;
    final token = ++_reverseGeocodeToken;
    unawaited(_resolveAddress(geocoder, point, token));
  }

  Future<void> _resolveAddress(
    ReverseGeocoder geocoder,
    LocationPoint point,
    int token,
  ) async {
    String? address;
    try {
      address = await geocoder.reverseGeocode(
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } on Object {
      // Defensive even though ReverseGeocoder's contract is never-throwing:
      // test doubles and future adapters must not affect pin confirmation.
      return;
    }
    if (_disposed || token != _reverseGeocodeToken) return;
    if (_center.latitude != point.latitude ||
        _center.longitude != point.longitude) {
      return;
    }
    final normalized = address?.trim();
    if (normalized == null || normalized.isEmpty) return;
    _center = LocationPoint(
      latitude: point.latitude,
      longitude: point.longitude,
      address: normalized,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reverseGeocodeToken++;
    super.dispose();
  }
}
