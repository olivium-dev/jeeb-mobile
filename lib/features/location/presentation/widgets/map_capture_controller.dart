import 'package:flutter/foundation.dart';

import '../../data/location_repository.dart';

class MapCaptureController extends ChangeNotifier {
  MapCaptureController({required LocationPoint initial}) : _center = initial;

  LocationPoint _center;

  LocationPoint get center => _center;

  void updateCenter(LocationPoint next) {
    if (next == _center) return;
    _center = next;
    notifyListeners();
  }
}
