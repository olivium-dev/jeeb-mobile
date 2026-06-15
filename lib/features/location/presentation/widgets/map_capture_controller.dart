import 'package:flutter/foundation.dart';

import '../../data/location_repository.dart';

/// Holds the live centre of the drop-off capture map so the screen's bottom
/// "Pin Location" CTA can read the coordinate the user parked under the fixed
/// centre pin. [GoogleMapCaptureView] writes [center] on every camera-idle;
/// the launcher reads it when the CTA fires.
///
/// Kept plugin-free (no `LatLng`) so the screen, launcher, and tests depend
/// only on the domain [LocationPoint] — the map widget is the single place that
/// translates to/from `google_maps_flutter` types.
class MapCaptureController extends ChangeNotifier {
  MapCaptureController({required LocationPoint initial}) : _center = initial;

  LocationPoint _center;

  /// The current map centre (== the point under the fixed centre pin).
  LocationPoint get center => _center;

  /// Called by [GoogleMapCaptureView] on every camera-idle. No-op (and no
  /// notification) when the value is unchanged, so listeners don't churn.
  void updateCenter(LocationPoint next) {
    if (next == _center) return;
    _center = next;
    notifyListeners();
  }
}
