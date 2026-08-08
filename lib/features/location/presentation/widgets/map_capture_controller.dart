import 'package:flutter/foundation.dart';

import '../../data/location_repository.dart';

class MapCaptureController extends ChangeNotifier {
  MapCaptureController({required LocationPoint initial}) : _center = initial;

  LocationPoint _center;
  bool _ready = false;

  LocationPoint get center => _center;

  /// True once the live camera has reported at least one `onCameraIdle`.
  /// Gates the confirm CTA so a pre-idle tap can never hand back a false pin.
  bool get isReady => _ready;

  void updateCenter(LocationPoint next) {
    if (next == _center) return;
    _center = next;
    notifyListeners();
  }

  /// Marks the camera settled. Idempotent; fires listeners once.
  void markReady() {
    if (_ready) return;
    _ready = true;
    notifyListeners();
  }
}
