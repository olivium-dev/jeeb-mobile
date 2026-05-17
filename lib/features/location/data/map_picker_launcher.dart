import 'location_repository.dart';

/// Port the location-picker screen uses to push an interactive map picker
/// and receive the chosen point back. The production adapter wraps
/// `ofl_geo_capture` (geocapture-flutter) — the feature itself never imports
/// the package directly, which keeps the cubit and screen pure and keeps
/// flutter analyze green even when the package isn't yet resolvable in this
/// worktree (the omds-flutter pattern; the geocapture-flutter equivalent
/// lands in a follow-up CI ticket).
///
/// Implementations must:
///   - Resolve `null` if the user cancelled the map picker.
///   - Use [initial] as the starting camera position when non-null.
///   - Push the picker as a full-screen modal (the package's `GeoCaptureScreen`
///     does this — the adapter is a thin wrapper over `Navigator.push`).
abstract class MapPickerLauncher {
  Future<LocationPoint?> pickOnMap({LocationPoint? initial});
}
