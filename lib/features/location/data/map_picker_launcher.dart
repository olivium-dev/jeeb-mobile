import 'location_repository.dart';

abstract class MapPickerLauncher {
  Future<LocationPoint?> pickOnMap({LocationPoint? initial});
}
